#!/usr/bin/env python3
"""Run Selenium-based visual/debug interaction sweeps on the packet analyzer.

The goal is not just a smoke test. This script simulates repeated "human"
click paths starting from the base configuration, captures screenshots for each
depth, and records the in-page debug overlay state plus browser console logs.
"""

from __future__ import annotations

import argparse
import html
import json
import random
import shutil
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from selenium import webdriver
from selenium.common.exceptions import ElementClickInterceptedException, NoSuchElementException, StaleElementReferenceException, TimeoutException
from selenium.webdriver import ActionChains
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.select import Select
from selenium.webdriver.support.ui import WebDriverWait


@dataclass
class StepResult:
    label: str
    screenshot: str
    debug_state: dict[str, Any]


def with_debug_flag(url: str, force_scrollbars: bool = False) -> str:
    parsed = urlparse(url)
    query = dict(parse_qsl(parsed.query, keep_blank_values=True))
    query["debug"] = "1"
    if force_scrollbars:
        query["force_scrollbars"] = "1"
    return urlunparse(parsed._replace(query=urlencode(query)))


def choose_binary_location() -> str | None:
    for candidate in ["chromium", "chromium-browser", "google-chrome", "google-chrome-stable"]:
        path = shutil.which(candidate)
        if path:
            return path
    return None


def create_driver() -> webdriver.Chrome:
    options = Options()
    binary = choose_binary_location()
    if binary:
        options.binary_location = binary
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--window-size=1600,1200")
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    return webdriver.Chrome(options=options)


def wait_ready(driver: webdriver.Chrome, timeout: float = 20.0) -> None:
    WebDriverWait(driver, timeout).until(
        lambda drv: drv.execute_script(
            "return !!(window.__packetAnalyzerDebug && "
            "window.__packetAnalyzerDebug.getState && "
            "window.__packetAnalyzerDebug.getState().ready);"
        )
    )
    WebDriverWait(driver, timeout).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, ".trace-row[data-row-id]"))
    )


def debug_state(driver: webdriver.Chrome) -> dict[str, Any]:
    return driver.execute_script(
        "return window.__packetAnalyzerDebug ? window.__packetAnalyzerDebug.getState() : {};"
    )


def save_step(
    driver: webdriver.Chrome,
    out_dir: Path,
    sequence_name: str,
    label: str,
    capture_screenshot: bool = True,
) -> StepResult:
    safe_label = label.replace(" ", "_").replace("/", "_")
    screenshot_name = f"{sequence_name}_{safe_label}.png"
    if capture_screenshot:
        driver.save_screenshot(str(out_dir / screenshot_name))
    else:
        screenshot_name = ""
    return StepResult(label=label, screenshot=screenshot_name, debug_state=debug_state(driver))


def safe_click(driver: webdriver.Chrome, element: Any) -> None:
    driver.execute_script(
        "arguments[0].scrollIntoView({block:'center', inline:'center'});",
        element,
    )
    time.sleep(0.1)
    try:
        element.click()
    except ElementClickInterceptedException:
        driver.execute_script(
            "arguments[0].dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true, view:window}));",
            element,
        )


def first_visible_rows(driver: webdriver.Chrome, count: int = 12) -> list[Any]:
    ensure_surface(driver, "trace")
    return driver.find_elements(By.CSS_SELECTOR, ".trace-row[data-row-id]")[:count]


def first_visible_field(driver: webdriver.Chrome) -> Any:
    rows = first_visible_rows(driver, count=4)
    for row in rows:
      fields = row.find_elements(By.CSS_SELECTOR, "[data-field-card='1']")
      if fields:
          return fields[0]
    raise NoSuchElementException("No visible field card found")


def click_row_index(index: int) -> Callable[[webdriver.Chrome, random.Random], str]:
    def inner(driver: webdriver.Chrome, rng: random.Random) -> str:
        rows = first_visible_rows(driver, count=max(index + 1, 10))
        safe_click(driver, rows[min(index, len(rows) - 1)])
        return f"row_{min(index, len(rows) - 1)}"

    return inner


def click_tab(label: str) -> Callable[[webdriver.Chrome, random.Random], str]:
    def inner(driver: webdriver.Chrome, rng: random.Random) -> str:
        safe_click(
            driver,
            driver.find_element(By.XPATH, f"//button[contains(@class,'side-tab')][normalize-space()='{label}']"),
        )
        return label

    return inner


def click_button(action: str, value: str) -> Callable[[webdriver.Chrome, random.Random], str]:
    def inner(driver: webdriver.Chrome, rng: random.Random) -> str:
        safe_click(
            driver,
            driver.find_element(By.CSS_SELECTOR, f"[data-action='{action}'][data-value='{value}']"),
        )
        return f"{action}:{value}"

    return inner


def ensure_surface(driver: webdriver.Chrome, value: str) -> None:
    state = debug_state(driver)
    if state.get("surfaceMode") == value:
        return
    safe_click(driver, driver.find_element(By.CSS_SELECTOR, f"[data-action='surface-mode'][data-value='{value}']"))
    if value == "wave":
        WebDriverWait(driver, 10).until(
            lambda drv: drv.find_elements(By.CSS_SELECTOR, ".wave-panel [data-wave-target-row-id], .wave-panel [data-wave-row-id], .wave-display svg")
        )
        return
    wait_ready(driver, timeout=10.0)


def pane_scoped_button(
    pane_label: str,
    action: str,
    value: str,
) -> Callable[[webdriver.Chrome, random.Random], str]:
    def inner(driver: webdriver.Chrome, rng: random.Random) -> str:
        click_tab(pane_label)(driver, rng)
        driver.find_element(By.CSS_SELECTOR, f"[data-action='{action}'][data-value='{value}']").click()
        return f"{pane_label}:{action}:{value}"

    return inner


def change_lane(driver: webdriver.Chrome, rng: random.Random) -> str:
    select = Select(driver.find_element(By.CSS_SELECTOR, "select[data-action='lane-change']"))
    options = [opt.get_attribute("value") for opt in select.options]
    state = debug_state(driver)
    current = str(state.get("lane", options[0]))
    candidates = [value for value in options if value != current]
    target = rng.choice(candidates or options)
    select.select_by_value(target)
    wait_ready(driver)
    return f"lane:{target}"


def change_decode(driver: webdriver.Chrome, rng: random.Random) -> str:
    select = Select(driver.find_element(By.CSS_SELECTOR, "select[data-action='decode-change']"))
    current = select.first_selected_option.get_attribute("value")
    options = [opt.get_attribute("value") for opt in select.options if opt.get_attribute("value") != current]
    target = rng.choice(options or [current])
    select.select_by_value(target)
    return f"decode:{target}"


def expand_selected(driver: webdriver.Chrome, rng: random.Random) -> str:
    ensure_surface(driver, "trace")
    driver.find_element(By.CSS_SELECTOR, ".trace-row.selected [data-action='toggle-row']").click()
    return "expand-selected"


def hold_expand(driver: webdriver.Chrome, rng: random.Random) -> str:
    ensure_surface(driver, "trace")
    expander = driver.find_element(By.CSS_SELECTOR, ".trace-row.selected [data-action='toggle-row']")
    ActionChains(driver).click_and_hold(expander).pause(0.65).release().perform()
    return "hold-expand-kind"


def spec_next(driver: webdriver.Chrome, rng: random.Random) -> str:
    click_tab("Spec View")(driver, rng)
    driver.find_element(By.XPATH, "//button[@data-action='packet-nav' and normalize-space()='Next']").click()
    return "spec-next"


def scroll_trace(driver: webdriver.Chrome, rng: random.Random) -> str:
    ensure_surface(driver, "trace")
    driver.execute_script(
        "const el=document.querySelector('[data-role=\"trace-scroll\"]');"
        "if(el){el.scrollTop += Math.floor(el.clientHeight * 0.8);}"
    )
    time.sleep(0.25)
    return "scroll-trace"


def toggle_tracker_sync(driver: webdriver.Chrome, rng: random.Random) -> str:
    click_tab("Link Tracker")(driver, rng)
    safe_click(driver, driver.find_element(By.CSS_SELECTOR, "[data-action='tracker-sync']"))
    return "tracker-sync-toggle"


def assert_scrollbars(expected_ids: list[str]) -> Callable[[webdriver.Chrome, random.Random], str]:
    def inner(driver: webdriver.Chrome, rng: random.Random) -> str:
        metrics = driver.execute_script(
            """
            const ids = arguments[0];
            return ids.map((id) => {
              const rail = document.querySelector(`[data-scroll-rail="${id}"]`);
              const thumb = document.querySelector(`[data-scroll-thumb="${id}"]`);
              if (!rail || !thumb) {
                return {id, ok: false, reason: "missing"};
              }
              const railRect = rail.getBoundingClientRect();
              const thumbRect = thumb.getBoundingClientRect();
              const railStyle = getComputedStyle(rail);
              return {
                id,
                ok: railRect.height >= 24 && thumbRect.height >= 20 && railStyle.opacity !== "0",
                railHeight: railRect.height,
                thumbHeight: thumbRect.height,
                opacity: railStyle.opacity,
              };
            });
            """,
            expected_ids,
        )
        failures = [item for item in metrics if not item.get("ok")]
        if failures:
            raise NoSuchElementException(f"Persistent scrollbar validation failed: {failures}")
        return "scrollbars:" + ",".join(item["id"] for item in metrics)

    return inner


def context_action(driver: webdriver.Chrome, rng: random.Random) -> str:
    field = first_visible_field(driver)
    ActionChains(driver).context_click(field).perform()
    WebDriverWait(driver, 5).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, ".context-menu"))
    )
    for action_name in ["move-right", "move-left", "toggle-default", "zero-time"]:
        items = driver.find_elements(
            By.CSS_SELECTOR,
            f".context-menu [data-menu-action='{action_name}'][data-disabled='0']",
        )
        if items:
            safe_click(driver, items[0])
            return f"context:{action_name}"
    raise NoSuchElementException("No enabled context menu item found")


def first_wave_interactive(driver: webdriver.Chrome) -> Any:
    ensure_surface(driver, "wave")
    def locate(drv: webdriver.Chrome) -> Any:
        candidates = (
            drv.find_elements(By.CSS_SELECTOR, "[data-wave-target-row-id]") or
            drv.find_elements(By.CSS_SELECTOR, "[data-wave-row-id]")
        )
        return candidates[0] if candidates else False

    return WebDriverWait(driver, 20).until(locate)


def wave_context_action(driver: webdriver.Chrome, rng: random.Random) -> str:
    target = first_wave_interactive(driver)
    ActionChains(driver).context_click(target).perform()
    WebDriverWait(driver, 5).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, ".context-menu"))
    )
    for action_name in ["link-row", "wave-open-details", "wave-open-spec", "wave-open-tracker", "wave-zero-time", "wave-show-tooltip"]:
        items = driver.find_elements(
            By.CSS_SELECTOR,
            f".context-menu [data-menu-action='{action_name}'][data-disabled='0']",
        )
        if items:
            safe_click(driver, items[0])
            return f"wave-context:{action_name}"
    raise NoSuchElementException("No enabled wave context menu item found")


def random_wave_beat(driver: webdriver.Chrome, rng: random.Random) -> str:
    ensure_surface(driver, "wave")
    beats = driver.find_elements(By.CSS_SELECTOR, "[data-wave-target-row-id]")
    if not beats:
        raise NoSuchElementException("No wave beat with link target found")
    before = debug_state(driver)
    before_tab = before.get("viewTab")
    target = rng.choice(beats[: min(len(beats), 40)])
    target_row = target.get_attribute("data-wave-target-row-id") or ""
    target_word = target.get_attribute("data-wave-word-id") or ""
    safe_click(driver, target)
    WebDriverWait(driver, 10).until(
        lambda drv: debug_state(drv).get("selectedRowId") == target_row
    )
    after = debug_state(driver)
    if after.get("surfaceMode") != "wave":
        raise AssertionError(f"Wave click switched surface unexpectedly: {after}")
    if after.get("viewTab") != before_tab:
        raise AssertionError(f"Wave click changed active tab unexpectedly: before={before_tab} after={after.get('viewTab')}")
    if target_word and after.get("selectedWordId") != target_word:
        raise AssertionError(f"Wave click selected wrong word: expected {target_word}, got {after.get('selectedWordId')}")
    return f"wave-click:{target_row}:{target_word or 'row'}"


def wave_panel_action(action: str) -> Callable[[webdriver.Chrome, random.Random], str]:
    def inner(driver: webdriver.Chrome, rng: random.Random) -> str:
        ensure_surface(driver, "wave")
        buttons = driver.find_elements(By.CSS_SELECTOR, f".wave-panel [data-action='{action}']")
        if not buttons:
            raise NoSuchElementException(f"No wave panel button found for {action}")
        safe_click(driver, rng.choice(buttons[: min(len(buttons), 6)]))
        return action

    return inner


def wait_after_action(driver: webdriver.Chrome) -> None:
    time.sleep(0.3)
    try:
        wait_ready(driver, timeout=10.0)
    except TimeoutException:
        pass


def browser_errors(driver: webdriver.Chrome) -> list[dict[str, Any]]:
    logs = []
    try:
        logs = driver.get_log("browser")
    except Exception:
        return []
    severe = []
    for entry in logs:
        level = entry.get("level", "")
        if level in {"SEVERE", "WARNING"}:
            severe.append(entry)
    return severe


def write_report(out_dir: Path, url: str, report: dict[str, Any]) -> None:
    (out_dir / "report.json").write_text(json.dumps(report, indent=2))
    summary_lines = [
        f"URL: {url}",
        f"Seed: {report['seed']}",
        f"Sequences: {len(report['sequences'])}",
        f"Browser log entries: {len(report['browser_logs'])}",
        f"App debug errors: {len(report['app_errors'])}",
    ]
    (out_dir / "summary.txt").write_text("\n".join(summary_lines) + "\n")

    sections = []
    for sequence in report["sequences"]:
        step_cards = []
        for step in sequence["steps"]:
            state = step["debug_state"]
            image_html = (
                f"<img src='{html.escape(step['screenshot'])}' alt='{html.escape(step['label'])}'>"
                if step["screenshot"]
                else "<div class='step-no-image'>screenshot skipped</div>"
            )
            step_cards.append(
                "<div class='step'>"
                f"<h4>{html.escape(step['label'])}</h4>"
                f"{image_html}"
                "<pre>"
                f"lane={html.escape(str(state.get('lane')))} "
                f"tab={html.escape(str(state.get('viewTab')))} "
                f"selected={html.escape(str(state.get('selectedRowId')))}\n"
                f"tracker={html.escape(str(state.get('trackerFormat')))} "
                f"density={html.escape(str(state.get('trackerDensity')))} "
                f"visible={html.escape(str(state.get('visiblePacketCount')))}\n"
                f"errors={html.escape(str(len(state.get('errors', []))))}"
                "</pre>"
                "</div>"
            )
        sections.append(
            "<section class='sequence'>"
            f"<h2>{html.escape(sequence['name'])}</h2>"
            f"<p>{html.escape(', '.join(sequence['actions']))}</p>"
            "<div class='steps'>"
            + "".join(step_cards)
            + "</div></section>"
        )

    html_text = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Packet Analyzer Visual Debug Report</title>
  <style>
    body {{
      margin: 0;
      padding: 24px;
      font: 14px sans-serif;
      background: #111722;
      color: #edf1f7;
    }}
    a {{ color: #9fd1ff; }}
    pre {{
      white-space: pre-wrap;
      background: #0b1018;
      padding: 8px;
      border: 1px solid #253347;
    }}
    .sequence {{
      margin-bottom: 28px;
      padding: 16px;
      background: #182130;
      border: 1px solid #2b3d54;
    }}
    .steps {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 16px;
    }}
    .step img {{
      width: 100%;
      border: 1px solid #2b3d54;
      display: block;
      background: #fff;
    }}
    .step-no-image {{
      padding: 14px;
      border: 1px dashed #405268;
      color: #9fb6cf;
      background: #111722;
      text-align: center;
      font-style: italic;
    }}
  </style>
</head>
<body>
  <h1>Packet Analyzer Visual Debug Report</h1>
  <p>URL: <a href="{html.escape(url)}">{html.escape(url)}</a></p>
  <p>Seed: {report['seed']} | sequences: {len(report['sequences'])} | browser logs: {len(report['browser_logs'])} | app errors: {len(report['app_errors'])}</p>
  {''.join(sections)}
  <h2>Browser Logs</h2>
  <pre>{html.escape(json.dumps(report['browser_logs'], indent=2))}</pre>
  <h2>App Errors</h2>
  <pre>{html.escape(json.dumps(report['app_errors'], indent=2))}</pre>
</body>
</html>
"""
    (out_dir / "index.html").write_text(html_text)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run packet-analyzer visual/debug interaction sweeps.")
    parser.add_argument("--url", required=True, help="Served packet analyzer URL")
    parser.add_argument("--out-dir", required=True, help="Output directory for screenshots and reports")
    parser.add_argument("--seed", type=int, default=260422, help="Deterministic random seed")
    parser.add_argument("--random-sequences", type=int, default=8, help="Number of random 3-step sequences")
    parser.add_argument("--depth", type=int, default=3, help="Click depth per sequence")
    parser.add_argument(
        "--force-persistent-scrollbars",
        action="store_true",
        help="Append force_scrollbars=1 so the Safari/custom scrollbar path can be visually validated",
    )
    parser.add_argument(
        "--skip-screenshots",
        action="store_true",
        help="Run the interaction/assertion sweep without writing per-step screenshots.",
    )
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    url = with_debug_flag(args.url, force_scrollbars=args.force_persistent_scrollbars)

    targeted_sequences: list[tuple[str, list[Callable[[webdriver.Chrome, random.Random], str]]]] = [
        ("spec_flow", [click_row_index(3), pane_scoped_button("Spec View", "spec-mode", "bin"), spec_next]),
        ("tracker_flow", [click_tab("Link Tracker"), pane_scoped_button("Link Tracker", "tracker-format", "desc"), pane_scoped_button("Link Tracker", "tracker-density", "2x")]),
        ("context_flow", [click_row_index(0), expand_selected, context_action]),
        ("lane_decode_flow", [change_lane, change_decode, click_tab("Details View")]),
        ("wave_flow", [click_button("surface-mode", "wave"), wave_context_action, wave_context_action]),
        ("wave_spec_sync", [click_button("surface-mode", "wave"), click_tab("Spec View"), random_wave_beat]),
        ("wave_details_sync", [click_button("surface-mode", "wave"), click_tab("Details View"), random_wave_beat]),
        ("wave_tracker_sync", [click_button("surface-mode", "wave"), click_tab("Link Tracker"), random_wave_beat]),
        ("scrollbar_flow", [assert_scrollbars(["trace", "side"]), scroll_trace, click_button("surface-mode", "wave"), assert_scrollbars(["wave", "side"])]),
    ]
    random_actions: list[Callable[[webdriver.Chrome, random.Random], str]] = [
        click_row_index(1),
        click_row_index(5),
        click_tab("Spec View"),
        click_tab("Details View"),
        click_tab("Link Tracker"),
        click_button("surface-mode", "trace"),
        click_button("surface-mode", "wave"),
        lambda drv, rnd: pane_scoped_button("Spec View", "spec-mode", rnd.choice(["hex", "bin"]))(drv, rnd),
        lambda drv, rnd: pane_scoped_button("Details View", "details-radix", rnd.choice(["hex", "dec"]))(drv, rnd),
        lambda drv, rnd: pane_scoped_button("Link Tracker", "tracker-format", rnd.choice(["fields", "hex", "bin", "desc"]))(drv, rnd),
        lambda drv, rnd: pane_scoped_button("Link Tracker", "tracker-density", rnd.choice(["1x", "2x", "4x"]))(drv, rnd),
        toggle_tracker_sync,
        scroll_trace,
        change_lane,
        change_decode,
        expand_selected,
        hold_expand,
        context_action,
        random_wave_beat,
        wave_context_action,
        wave_panel_action("wave-prev"),
        wave_panel_action("wave-next"),
        wave_panel_action("wave-zoom-in"),
        wave_panel_action("wave-zoom-out"),
        wave_panel_action("wave-zoom-reset"),
    ]

    report: dict[str, Any] = {
        "url": url,
        "seed": args.seed,
        "sequences": [],
        "browser_logs": [],
        "app_errors": [],
    }

    driver = create_driver()
    try:
        for name, actions in targeted_sequences + [
            (f"random_{index:02d}", [rng.choice(random_actions) for _ in range(args.depth)])
            for index in range(args.random_sequences)
        ]:
            print(f"running {name}", flush=True)
            driver.get(url)
            wait_ready(driver)
            steps = [save_step(driver, out_dir, name, "base", capture_screenshot=not args.skip_screenshots)]
            action_names: list[str] = []
            for depth_index, action in enumerate(actions, start=1):
                try:
                    action_name = action(driver, rng)
                except StaleElementReferenceException:
                    time.sleep(0.2)
                    action_name = action(driver, rng)
                action_names.append(action_name)
                wait_after_action(driver)
                steps.append(save_step(driver, out_dir, name, f"step{depth_index}_{action_name}", capture_screenshot=not args.skip_screenshots))

            report["sequences"].append(
                {
                    "name": name,
                    "actions": action_names,
                    "steps": [
                        {
                            "label": step.label,
                            "screenshot": step.screenshot,
                            "debug_state": step.debug_state,
                        }
                        for step in steps
                    ],
                }
            )
            report["browser_logs"].extend(browser_errors(driver))

        final_state = debug_state(driver)
        report["app_errors"] = final_state.get("errors", [])
    finally:
        driver.quit()

    write_report(out_dir, url, report)

    if report["browser_logs"] or report["app_errors"]:
        print(f"Visual debug report written to {out_dir} with runtime issues detected")
        return 1

    print(f"Visual debug report written to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
