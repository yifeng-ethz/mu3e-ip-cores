case 9:      AE("&Tab;");                  break; /* \t */
case 10:     AE("&NewLine;");              break; /* \n */
case 33:     AE("&excl;");                 break; /* ! */
/* quot aka QUOT */
case 34:     AE("&quot;");                 break; /* " */
case 35:     AE("&num;");                  break; /* # */
case 36:     AE("&dollar;");               break; /* $ */
case 37:     AE("&percnt;");               break; /* % */
/* amp aka AMP */
case 38:     AE("&amp;");                  break; /* & */
case 39:     AE("&apos;");                 break; /* ' */
case 40:     AE("&lpar;");                 break; /* ( */
case 41:     AE("&rpar;");                 break; /* ) */
/* ast aka midast */
case 42:     AE("&ast;");                  break; /* * */
case 43:     AE("&plus;");                 break; /* + */
case 44:     AE("&comma;");                break; /* , */
case 46:     AE("&period;");               break; /* . */
case 47:     AE("&sol;");                  break; /* / */
case 58:     AE("&colon;");                break; /* : */
case 59:     AE("&semi;");                 break; /* ; */
case 60:     TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvlt;"); MCP;                        /* <⃒ */
    } else {
        /* lt aka LT */
        AE("&lt;");                               /* < */
    };                                     break;
case 61:     TWOCPE;
    if (clen2 && uniChar2 == 8421) { 
        AE("&bne;"); MCP;                         /* =⃥ */
    } else {
        AE("&equals;");                           /* = */
    };                                     break;
case 62:     TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvgt;"); MCP;                        /* >⃒ */
    } else {
        /* gt aka GT */
        AE("&gt;");                               /* > */
    };                                     break;
case 63:     AE("&quest;");                break; /* ? */
case 64:     AE("&commat;");               break; /* @ */
/* lsqb aka lbrack */
case 91:     AE("&lsqb;");                 break; /* [ */
case 92:     AE("&bsol;");                 break; /* \ */
/* rsqb aka rbrack */
case 93:     AE("&rsqb;");                 break; /* ] */
case 94:     AE("&Hat;");                  break; /* ^ */
/* lowbar aka UnderBar */
case 95:     AE("&lowbar;");               break; /* _ */
/* grave aka DiacriticalGrave */
case 96:     AE("&grave;");                break; /* ` */
case 102:    TWOCPE;
    if (uniChar2 == 106) {
        AE("&fjlig;"); MCP;                       /* fj */
    } else {charDone = 0;};                break;
/* lcub aka lbrace */
case 123:    AE("&lcub;");                 break; /* { */
/* vert aka VerticalLine or verbar */
case 124:    AE("&vert;");                 break; /* | */
/* rcub aka rbrace */
case 125:    AE("&rcub;");                 break; /* } */
/* nbsp aka NonBreakingSpace */
case 160:    AE("&nbsp;");                 break; /*   */
case 161:    AE("&iexcl;");                break; /* ¡ */
case 162:    AE("&cent;");                 break; /* ¢ */
case 163:    AE("&pound;");                break; /* £ */
case 164:    AE("&curren;");               break; /* ¤ */
case 165:    AE("&yen;");                  break; /* ¥ */
case 166:    AE("&brvbar;");               break; /* ¦ */
case 167:    AE("&sect;");                 break; /* § */
/* die aka Dot or DoubleDot or uml */
case 168:    AE("&die;");                  break; /* ¨ */
/* copy aka COPY */
case 169:    AE("&copy;");                 break; /* © */
case 170:    AE("&ordf;");                 break; /* ª */
case 171:    AE("&laquo;");                break; /* « */
case 172:    AE("&not;");                  break; /* ¬ */
case 173:    AE("&shy;");                  break; /* ­ */
/* reg aka REG or circledR */
case 174:    AE("&reg;");                  break; /* ® */
/* macr aka strns */
case 175:    AE("&macr;");                 break; /* ¯ */
case 176:    AE("&deg;");                  break; /* ° */
/* pm aka PlusMinus or plusmn */
case 177:    AE("&pm;");                   break; /* ± */
case 178:    AE("&sup2;");                 break; /* ² */
case 179:    AE("&sup3;");                 break; /* ³ */
/* acute aka DiacriticalAcute */
case 180:    AE("&acute;");                break; /* ´ */
case 181:    AE("&micro;");                break; /* µ */
case 182:    AE("&para;");                 break; /* ¶ */
/* middot aka CenterDot or centerdot */
case 183:    AE("&middot;");               break; /* · */
/* cedil aka Cedilla */
case 184:    AE("&cedil;");                break; /* ¸ */
case 185:    AE("&sup1;");                 break; /* ¹ */
case 186:    AE("&ordm;");                 break; /* º */
case 187:    AE("&raquo;");                break; /* » */
case 188:    AE("&frac14;");               break; /* ¼ */
/* half aka frac12 */
case 189:    AE("&half;");                 break; /* ½ */
case 190:    AE("&frac34;");               break; /* ¾ */
case 191:    AE("&iquest;");               break; /* ¿ */
case 192:    AE("&Agrave;");               break; /* À */
case 193:    AE("&Aacute;");               break; /* Á */
case 194:    AE("&Acirc;");                break; /* Â */
case 195:    AE("&Atilde;");               break; /* Ã */
case 196:    AE("&Auml;");                 break; /* Ä */
/* angst aka Aring */
case 197:    AE("&angst;");                break; /* Å */
case 198:    AE("&AElig;");                break; /* Æ */
case 199:    AE("&Ccedil;");               break; /* Ç */
case 200:    AE("&Egrave;");               break; /* È */
case 201:    AE("&Eacute;");               break; /* É */
case 202:    AE("&Ecirc;");                break; /* Ê */
case 203:    AE("&Euml;");                 break; /* Ë */
case 204:    AE("&Igrave;");               break; /* Ì */
case 205:    AE("&Iacute;");               break; /* Í */
case 206:    AE("&Icirc;");                break; /* Î */
case 207:    AE("&Iuml;");                 break; /* Ï */
case 208:    AE("&ETH;");                  break; /* Ð */
case 209:    AE("&Ntilde;");               break; /* Ñ */
case 210:    AE("&Ograve;");               break; /* Ò */
case 211:    AE("&Oacute;");               break; /* Ó */
case 212:    AE("&Ocirc;");                break; /* Ô */
case 213:    AE("&Otilde;");               break; /* Õ */
case 214:    AE("&Ouml;");                 break; /* Ö */
case 215:    AE("&times;");                break; /* × */
case 216:    AE("&Oslash;");               break; /* Ø */
case 217:    AE("&Ugrave;");               break; /* Ù */
case 218:    AE("&Uacute;");               break; /* Ú */
case 219:    AE("&Ucirc;");                break; /* Û */
case 220:    AE("&Uuml;");                 break; /* Ü */
case 221:    AE("&Yacute;");               break; /* Ý */
case 222:    AE("&THORN;");                break; /* Þ */
case 223:    AE("&szlig;");                break; /* ß */
case 224:    AE("&agrave;");               break; /* à */
case 225:    AE("&aacute;");               break; /* á */
case 226:    AE("&acirc;");                break; /* â */
case 227:    AE("&atilde;");               break; /* ã */
case 228:    AE("&auml;");                 break; /* ä */
case 229:    AE("&aring;");                break; /* å */
case 230:    AE("&aelig;");                break; /* æ */
case 231:    AE("&ccedil;");               break; /* ç */
case 232:    AE("&egrave;");               break; /* è */
case 233:    AE("&eacute;");               break; /* é */
case 234:    AE("&ecirc;");                break; /* ê */
case 235:    AE("&euml;");                 break; /* ë */
case 236:    AE("&igrave;");               break; /* ì */
case 237:    AE("&iacute;");               break; /* í */
case 238:    AE("&icirc;");                break; /* î */
case 239:    AE("&iuml;");                 break; /* ï */
case 240:    AE("&eth;");                  break; /* ð */
case 241:    AE("&ntilde;");               break; /* ñ */
case 242:    AE("&ograve;");               break; /* ò */
case 243:    AE("&oacute;");               break; /* ó */
case 244:    AE("&ocirc;");                break; /* ô */
case 245:    AE("&otilde;");               break; /* õ */
case 246:    AE("&ouml;");                 break; /* ö */
/* div aka divide */
case 247:    AE("&div;");                  break; /* ÷ */
case 248:    AE("&oslash;");               break; /* ø */
case 249:    AE("&ugrave;");               break; /* ù */
case 250:    AE("&uacute;");               break; /* ú */
case 251:    AE("&ucirc;");                break; /* û */
case 252:    AE("&uuml;");                 break; /* ü */
case 253:    AE("&yacute;");               break; /* ý */
case 254:    AE("&thorn;");                break; /* þ */
case 255:    AE("&yuml;");                 break; /* ÿ */
case 256:    AE("&Amacr;");                break; /* Ā */
case 257:    AE("&amacr;");                break; /* ā */
case 258:    AE("&Abreve;");               break; /* Ă */
case 259:    AE("&abreve;");               break; /* ă */
case 260:    AE("&Aogon;");                break; /* Ą */
case 261:    AE("&aogon;");                break; /* ą */
case 262:    AE("&Cacute;");               break; /* Ć */
case 263:    AE("&cacute;");               break; /* ć */
case 264:    AE("&Ccirc;");                break; /* Ĉ */
case 265:    AE("&ccirc;");                break; /* ĉ */
case 266:    AE("&Cdot;");                 break; /* Ċ */
case 267:    AE("&cdot;");                 break; /* ċ */
case 268:    AE("&Ccaron;");               break; /* Č */
case 269:    AE("&ccaron;");               break; /* č */
case 270:    AE("&Dcaron;");               break; /* Ď */
case 271:    AE("&dcaron;");               break; /* ď */
case 272:    AE("&Dstrok;");               break; /* Đ */
case 273:    AE("&dstrok;");               break; /* đ */
case 274:    AE("&Emacr;");                break; /* Ē */
case 275:    AE("&emacr;");                break; /* ē */
case 278:    AE("&Edot;");                 break; /* Ė */
case 279:    AE("&edot;");                 break; /* ė */
case 280:    AE("&Eogon;");                break; /* Ę */
case 281:    AE("&eogon;");                break; /* ę */
case 282:    AE("&Ecaron;");               break; /* Ě */
case 283:    AE("&ecaron;");               break; /* ě */
case 284:    AE("&Gcirc;");                break; /* Ĝ */
case 285:    AE("&gcirc;");                break; /* ĝ */
case 286:    AE("&Gbreve;");               break; /* Ğ */
case 287:    AE("&gbreve;");               break; /* ğ */
case 288:    AE("&Gdot;");                 break; /* Ġ */
case 289:    AE("&gdot;");                 break; /* ġ */
case 290:    AE("&Gcedil;");               break; /* Ģ */
case 292:    AE("&Hcirc;");                break; /* Ĥ */
case 293:    AE("&hcirc;");                break; /* ĥ */
case 294:    AE("&Hstrok;");               break; /* Ħ */
case 295:    AE("&hstrok;");               break; /* ħ */
case 296:    AE("&Itilde;");               break; /* Ĩ */
case 297:    AE("&itilde;");               break; /* ĩ */
case 298:    AE("&Imacr;");                break; /* Ī */
case 299:    AE("&imacr;");                break; /* ī */
case 302:    AE("&Iogon;");                break; /* Į */
case 303:    AE("&iogon;");                break; /* į */
case 304:    AE("&Idot;");                 break; /* İ */
/* imath aka inodot */
case 305:    AE("&imath;");                break; /* ı */
case 306:    AE("&IJlig;");                break; /* Ĳ */
case 307:    AE("&ijlig;");                break; /* ĳ */
case 308:    AE("&Jcirc;");                break; /* Ĵ */
case 309:    AE("&jcirc;");                break; /* ĵ */
case 310:    AE("&Kcedil;");               break; /* Ķ */
case 311:    AE("&kcedil;");               break; /* ķ */
case 312:    AE("&kgreen;");               break; /* ĸ */
case 313:    AE("&Lacute;");               break; /* Ĺ */
case 314:    AE("&lacute;");               break; /* ĺ */
case 315:    AE("&Lcedil;");               break; /* Ļ */
case 316:    AE("&lcedil;");               break; /* ļ */
case 317:    AE("&Lcaron;");               break; /* Ľ */
case 318:    AE("&lcaron;");               break; /* ľ */
case 319:    AE("&Lmidot;");               break; /* Ŀ */
case 320:    AE("&lmidot;");               break; /* ŀ */
case 321:    AE("&Lstrok;");               break; /* Ł */
case 322:    AE("&lstrok;");               break; /* ł */
case 323:    AE("&Nacute;");               break; /* Ń */
case 324:    AE("&nacute;");               break; /* ń */
case 325:    AE("&Ncedil;");               break; /* Ņ */
case 326:    AE("&ncedil;");               break; /* ņ */
case 327:    AE("&Ncaron;");               break; /* Ň */
case 328:    AE("&ncaron;");               break; /* ň */
case 329:    AE("&napos;");                break; /* ŉ */
case 330:    AE("&ENG;");                  break; /* Ŋ */
case 331:    AE("&eng;");                  break; /* ŋ */
case 332:    AE("&Omacr;");                break; /* Ō */
case 333:    AE("&omacr;");                break; /* ō */
case 336:    AE("&Odblac;");               break; /* Ő */
case 337:    AE("&odblac;");               break; /* ő */
case 338:    AE("&OElig;");                break; /* Œ */
case 339:    AE("&oelig;");                break; /* œ */
case 340:    AE("&Racute;");               break; /* Ŕ */
case 341:    AE("&racute;");               break; /* ŕ */
case 342:    AE("&Rcedil;");               break; /* Ŗ */
case 343:    AE("&rcedil;");               break; /* ŗ */
case 344:    AE("&Rcaron;");               break; /* Ř */
case 345:    AE("&rcaron;");               break; /* ř */
case 346:    AE("&Sacute;");               break; /* Ś */
case 347:    AE("&sacute;");               break; /* ś */
case 348:    AE("&Scirc;");                break; /* Ŝ */
case 349:    AE("&scirc;");                break; /* ŝ */
case 350:    AE("&Scedil;");               break; /* Ş */
case 351:    AE("&scedil;");               break; /* ş */
case 352:    AE("&Scaron;");               break; /* Š */
case 353:    AE("&scaron;");               break; /* š */
case 354:    AE("&Tcedil;");               break; /* Ţ */
case 355:    AE("&tcedil;");               break; /* ţ */
case 356:    AE("&Tcaron;");               break; /* Ť */
case 357:    AE("&tcaron;");               break; /* ť */
case 358:    AE("&Tstrok;");               break; /* Ŧ */
case 359:    AE("&tstrok;");               break; /* ŧ */
case 360:    AE("&Utilde;");               break; /* Ũ */
case 361:    AE("&utilde;");               break; /* ũ */
case 362:    AE("&Umacr;");                break; /* Ū */
case 363:    AE("&umacr;");                break; /* ū */
case 364:    AE("&Ubreve;");               break; /* Ŭ */
case 365:    AE("&ubreve;");               break; /* ŭ */
case 366:    AE("&Uring;");                break; /* Ů */
case 367:    AE("&uring;");                break; /* ů */
case 368:    AE("&Udblac;");               break; /* Ű */
case 369:    AE("&udblac;");               break; /* ű */
case 370:    AE("&Uogon;");                break; /* Ų */
case 371:    AE("&uogon;");                break; /* ų */
case 372:    AE("&Wcirc;");                break; /* Ŵ */
case 373:    AE("&wcirc;");                break; /* ŵ */
case 374:    AE("&Ycirc;");                break; /* Ŷ */
case 375:    AE("&ycirc;");                break; /* ŷ */
case 376:    AE("&Yuml;");                 break; /* Ÿ */
case 377:    AE("&Zacute;");               break; /* Ź */
case 378:    AE("&zacute;");               break; /* ź */
case 379:    AE("&Zdot;");                 break; /* Ż */
case 380:    AE("&zdot;");                 break; /* ż */
case 381:    AE("&Zcaron;");               break; /* Ž */
case 382:    AE("&zcaron;");               break; /* ž */
case 402:    AE("&fnof;");                 break; /* ƒ */
case 437:    AE("&imped;");                break; /* Ƶ */
case 501:    AE("&gacute;");               break; /* ǵ */
case 567:    AE("&jmath;");                break; /* ȷ */
case 710:    AE("&circ;");                 break; /* ˆ */
/* caron aka Hacek */
case 711:    AE("&caron;");                break; /* ˇ */
/* breve aka Breve */
case 728:    AE("&breve;");                break; /* ˘ */
/* dot aka DiacriticalDot */
case 729:    AE("&dot;");                  break; /* ˙ */
case 730:    AE("&ring;");                 break; /* ˚ */
case 731:    AE("&ogon;");                 break; /* ˛ */
/* tilde aka DiacriticalTilde */
case 732:    AE("&tilde;");                break; /* ˜ */
/* dblac aka DiacriticalDoubleAcute */
case 733:    AE("&dblac;");                break; /* ˝ */
case 785:    AE("&DownBreve;");            break; /* ̑ */
case 913:    AE("&Alpha;");                break; /* Α */
case 914:    AE("&Beta;");                 break; /* Β */
case 915:    AE("&Gamma;");                break; /* Γ */
case 916:    AE("&Delta;");                break; /* Δ */
case 917:    AE("&Epsilon;");              break; /* Ε */
case 918:    AE("&Zeta;");                 break; /* Ζ */
case 919:    AE("&Eta;");                  break; /* Η */
case 920:    AE("&Theta;");                break; /* Θ */
case 921:    AE("&Iota;");                 break; /* Ι */
case 922:    AE("&Kappa;");                break; /* Κ */
case 923:    AE("&Lambda;");               break; /* Λ */
case 924:    AE("&Mu;");                   break; /* Μ */
case 925:    AE("&Nu;");                   break; /* Ν */
case 926:    AE("&Xi;");                   break; /* Ξ */
case 927:    AE("&Omicron;");              break; /* Ο */
case 928:    AE("&Pi;");                   break; /* Π */
case 929:    AE("&Rho;");                  break; /* Ρ */
case 931:    AE("&Sigma;");                break; /* Σ */
case 932:    AE("&Tau;");                  break; /* Τ */
case 933:    AE("&Upsilon;");              break; /* Υ */
case 934:    AE("&Phi;");                  break; /* Φ */
case 935:    AE("&Chi;");                  break; /* Χ */
case 936:    AE("&Psi;");                  break; /* Ψ */
/* ohm aka Omega */
case 937:    AE("&ohm;");                  break; /* Ω */
case 945:    AE("&alpha;");                break; /* α */
case 946:    AE("&beta;");                 break; /* β */
case 947:    AE("&gamma;");                break; /* γ */
case 948:    AE("&delta;");                break; /* δ */
/* epsi aka epsilon */
case 949:    AE("&epsi;");                 break; /* ε */
case 950:    AE("&zeta;");                 break; /* ζ */
case 951:    AE("&eta;");                  break; /* η */
case 952:    AE("&theta;");                break; /* θ */
case 953:    AE("&iota;");                 break; /* ι */
case 954:    AE("&kappa;");                break; /* κ */
case 955:    AE("&lambda;");               break; /* λ */
case 956:    AE("&mu;");                   break; /* μ */
case 957:    AE("&nu;");                   break; /* ν */
case 958:    AE("&xi;");                   break; /* ξ */
case 959:    AE("&omicron;");              break; /* ο */
case 960:    AE("&pi;");                   break; /* π */
case 961:    AE("&rho;");                  break; /* ρ */
/* sigmaf aka sigmav or varsigma */
case 962:    AE("&sigmaf;");               break; /* ς */
case 963:    AE("&sigma;");                break; /* σ */
case 964:    AE("&tau;");                  break; /* τ */
/* upsi aka upsilon */
case 965:    AE("&upsi;");                 break; /* υ */
case 966:    AE("&phi;");                  break; /* φ */
case 967:    AE("&chi;");                  break; /* χ */
case 968:    AE("&psi;");                  break; /* ψ */
case 969:    AE("&omega;");                break; /* ω */
/* thetav aka thetasym or vartheta */
case 977:    AE("&thetav;");               break; /* ϑ */
/* Upsi aka upsih */
case 978:    AE("&Upsi;");                 break; /* ϒ */
/* phiv aka straightphi or varphi */
case 981:    AE("&phiv;");                 break; /* ϕ */
/* piv aka varpi */
case 982:    AE("&piv;");                  break; /* ϖ */
case 988:    AE("&Gammad;");               break; /* Ϝ */
/* gammad aka digamma */
case 989:    AE("&gammad;");               break; /* ϝ */
/* kappav aka varkappa */
case 1008:   AE("&kappav;");               break; /* ϰ */
/* rhov aka varrho */
case 1009:   AE("&rhov;");                 break; /* ϱ */
/* epsiv aka straightepsilon or varepsilon */
case 1013:   AE("&epsiv;");                break; /* ϵ */
/* bepsi aka backepsilon */
case 1014:   AE("&bepsi;");                break; /* ϶ */
case 1025:   AE("&IOcy;");                 break; /* Ё */
case 1026:   AE("&DJcy;");                 break; /* Ђ */
case 1027:   AE("&GJcy;");                 break; /* Ѓ */
case 1028:   AE("&Jukcy;");                break; /* Є */
case 1029:   AE("&DScy;");                 break; /* Ѕ */
case 1030:   AE("&Iukcy;");                break; /* І */
case 1031:   AE("&YIcy;");                 break; /* Ї */
case 1032:   AE("&Jsercy;");               break; /* Ј */
case 1033:   AE("&LJcy;");                 break; /* Љ */
case 1034:   AE("&NJcy;");                 break; /* Њ */
case 1035:   AE("&TSHcy;");                break; /* Ћ */
case 1036:   AE("&KJcy;");                 break; /* Ќ */
case 1038:   AE("&Ubrcy;");                break; /* Ў */
case 1039:   AE("&DZcy;");                 break; /* Џ */
case 1040:   AE("&Acy;");                  break; /* А */
case 1041:   AE("&Bcy;");                  break; /* Б */
case 1042:   AE("&Vcy;");                  break; /* В */
case 1043:   AE("&Gcy;");                  break; /* Г */
case 1044:   AE("&Dcy;");                  break; /* Д */
case 1045:   AE("&IEcy;");                 break; /* Е */
case 1046:   AE("&ZHcy;");                 break; /* Ж */
case 1047:   AE("&Zcy;");                  break; /* З */
case 1048:   AE("&Icy;");                  break; /* И */
case 1049:   AE("&Jcy;");                  break; /* Й */
case 1050:   AE("&Kcy;");                  break; /* К */
case 1051:   AE("&Lcy;");                  break; /* Л */
case 1052:   AE("&Mcy;");                  break; /* М */
case 1053:   AE("&Ncy;");                  break; /* Н */
case 1054:   AE("&Ocy;");                  break; /* О */
case 1055:   AE("&Pcy;");                  break; /* П */
case 1056:   AE("&Rcy;");                  break; /* Р */
case 1057:   AE("&Scy;");                  break; /* С */
case 1058:   AE("&Tcy;");                  break; /* Т */
case 1059:   AE("&Ucy;");                  break; /* У */
case 1060:   AE("&Fcy;");                  break; /* Ф */
case 1061:   AE("&KHcy;");                 break; /* Х */
case 1062:   AE("&TScy;");                 break; /* Ц */
case 1063:   AE("&CHcy;");                 break; /* Ч */
case 1064:   AE("&SHcy;");                 break; /* Ш */
case 1065:   AE("&SHCHcy;");               break; /* Щ */
case 1066:   AE("&HARDcy;");               break; /* Ъ */
case 1067:   AE("&Ycy;");                  break; /* Ы */
case 1068:   AE("&SOFTcy;");               break; /* Ь */
case 1069:   AE("&Ecy;");                  break; /* Э */
case 1070:   AE("&YUcy;");                 break; /* Ю */
case 1071:   AE("&YAcy;");                 break; /* Я */
case 1072:   AE("&acy;");                  break; /* а */
case 1073:   AE("&bcy;");                  break; /* б */
case 1074:   AE("&vcy;");                  break; /* в */
case 1075:   AE("&gcy;");                  break; /* г */
case 1076:   AE("&dcy;");                  break; /* д */
case 1077:   AE("&iecy;");                 break; /* е */
case 1078:   AE("&zhcy;");                 break; /* ж */
case 1079:   AE("&zcy;");                  break; /* з */
case 1080:   AE("&icy;");                  break; /* и */
case 1081:   AE("&jcy;");                  break; /* й */
case 1082:   AE("&kcy;");                  break; /* к */
case 1083:   AE("&lcy;");                  break; /* л */
case 1084:   AE("&mcy;");                  break; /* м */
case 1085:   AE("&ncy;");                  break; /* н */
case 1086:   AE("&ocy;");                  break; /* о */
case 1087:   AE("&pcy;");                  break; /* п */
case 1088:   AE("&rcy;");                  break; /* р */
case 1089:   AE("&scy;");                  break; /* с */
case 1090:   AE("&tcy;");                  break; /* т */
case 1091:   AE("&ucy;");                  break; /* у */
case 1092:   AE("&fcy;");                  break; /* ф */
case 1093:   AE("&khcy;");                 break; /* х */
case 1094:   AE("&tscy;");                 break; /* ц */
case 1095:   AE("&chcy;");                 break; /* ч */
case 1096:   AE("&shcy;");                 break; /* ш */
case 1097:   AE("&shchcy;");               break; /* щ */
case 1098:   AE("&hardcy;");               break; /* ъ */
case 1099:   AE("&ycy;");                  break; /* ы */
case 1100:   AE("&softcy;");               break; /* ь */
case 1101:   AE("&ecy;");                  break; /* э */
case 1102:   AE("&yucy;");                 break; /* ю */
case 1103:   AE("&yacy;");                 break; /* я */
case 1105:   AE("&iocy;");                 break; /* ё */
case 1106:   AE("&djcy;");                 break; /* ђ */
case 1107:   AE("&gjcy;");                 break; /* ѓ */
case 1108:   AE("&jukcy;");                break; /* є */
case 1109:   AE("&dscy;");                 break; /* ѕ */
case 1110:   AE("&iukcy;");                break; /* і */
case 1111:   AE("&yicy;");                 break; /* ї */
case 1112:   AE("&jsercy;");               break; /* ј */
case 1113:   AE("&ljcy;");                 break; /* љ */
case 1114:   AE("&njcy;");                 break; /* њ */
case 1115:   AE("&tshcy;");                break; /* ћ */
case 1116:   AE("&kjcy;");                 break; /* ќ */
case 1118:   AE("&ubrcy;");                break; /* ў */
case 1119:   AE("&dzcy;");                 break; /* џ */
case 8194:   AE("&ensp;");                 break; /*   */
case 8195:   AE("&emsp;");                 break; /*   */
case 8196:   AE("&emsp13;");               break; /*   */
case 8197:   AE("&emsp14;");               break; /*   */
case 8199:   AE("&numsp;");                break; /*   */
case 8200:   AE("&puncsp;");               break; /*   */
/* thinsp aka ThinSpace */
case 8201:   AE("&thinsp;");               break; /*   */
/* hairsp aka VeryThinSpace */
case 8202:   AE("&hairsp;");               break; /*   */
/* ZeroWidthSpace aka NegativeMediumSpace or NegativeThickSpace or NegativeThinSpace or NegativeVeryThinSpace */
case 8203:   AE("&ZeroWidthSpace;");       break; /* ​ */
case 8204:   AE("&zwnj;");                 break; /* ‌ */
case 8205:   AE("&zwj;");                  break; /* ‍ */
case 8206:   AE("&lrm;");                  break; /* ‎ */
case 8207:   AE("&rlm;");                  break; /* ‏ */
/* dash aka hyphen */
case 8208:   AE("&dash;");                 break; /* ‐ */
case 8211:   AE("&ndash;");                break; /* – */
case 8212:   AE("&mdash;");                break; /* — */
case 8213:   AE("&horbar;");               break; /* ― */
/* Vert aka Verbar */
case 8214:   AE("&Vert;");                 break; /* ‖ */
/* lsquo aka OpenCurlyQuote */
case 8216:   AE("&lsquo;");                break; /* ‘ */
/* rsquo aka CloseCurlyQuote or rsquor */
case 8217:   AE("&rsquo;");                break; /* ’ */
/* sbquo aka lsquor */
case 8218:   AE("&sbquo;");                break; /* ‚ */
/* ldquo aka OpenCurlyDoubleQuote */
case 8220:   AE("&ldquo;");                break; /* “ */
/* rdquo aka CloseCurlyDoubleQuote or rdquor */
case 8221:   AE("&rdquo;");                break; /* ” */
/* bdquo aka ldquor */
case 8222:   AE("&bdquo;");                break; /* „ */
case 8224:   AE("&dagger;");               break; /* † */
/* Dagger aka ddagger */
case 8225:   AE("&Dagger;");               break; /* ‡ */
/* bull aka bullet */
case 8226:   AE("&bull;");                 break; /* • */
case 8229:   AE("&nldr;");                 break; /* ‥ */
/* mldr aka hellip */
case 8230:   AE("&mldr;");                 break; /* … */
case 8240:   AE("&permil;");               break; /* ‰ */
case 8241:   AE("&pertenk;");              break; /* ‱ */
case 8242:   AE("&prime;");                break; /* ′ */
case 8243:   AE("&Prime;");                break; /* ″ */
case 8244:   AE("&tprime;");               break; /* ‴ */
/* bprime aka backprime */
case 8245:   AE("&bprime;");               break; /* ‵ */
case 8249:   AE("&lsaquo;");               break; /* ‹ */
case 8250:   AE("&rsaquo;");               break; /* › */
/* oline aka OverBar */
case 8254:   AE("&oline;");                break; /* ‾ */
case 8257:   AE("&caret;");                break; /* ⁁ */
case 8259:   AE("&hybull;");               break; /* ⁃ */
case 8260:   AE("&frasl;");                break; /* ⁄ */
case 8271:   AE("&bsemi;");                break; /* ⁏ */
case 8279:   AE("&qprime;");               break; /* ⁗ */
case 8287:   TWOCPE;
    if (clen2 && uniChar2 == 8202) { 
        AE("&ThickSpace;"); MCP;                  /*    */
    } else {
        AE("&MediumSpace;");                      /*   */
    };                                     break;
case 8288:   AE("&NoBreak;");              break; /* ⁠ */
/* af aka ApplyFunction */
case 8289:   AE("&af;");                   break; /* ⁡ */
/* it aka InvisibleTimes */
case 8290:   AE("&it;");                   break; /* ⁢ */
/* ic aka InvisibleComma */
case 8291:   AE("&ic;");                   break; /* ⁣ */
case 8364:   AE("&euro;");                 break; /* € */
/* tdot aka TripleDot */
case 8411:   AE("&tdot;");                 break; /* ⃛ */
case 8412:   AE("&DotDot;");               break; /* ⃜ */
/* Copf aka complexes */
case 8450:   AE("&Copf;");                 break; /* ℂ */
case 8453:   AE("&incare;");               break; /* ℅ */
case 8458:   AE("&gscr;");                 break; /* ℊ */
/* Hscr aka HilbertSpace or hamilt */
case 8459:   AE("&Hscr;");                 break; /* ℋ */
/* Hfr aka Poincareplane */
case 8460:   AE("&Hfr;");                  break; /* ℌ */
/* Hopf aka quaternions */
case 8461:   AE("&Hopf;");                 break; /* ℍ */
case 8462:   AE("&planckh;");              break; /* ℎ */
/* hbar aka hslash or planck or plankv */
case 8463:   AE("&hbar;");                 break; /* ℏ */
/* Iscr aka imagline */
case 8464:   AE("&Iscr;");                 break; /* ℐ */
/* Im aka Ifr or image or imagpart */
case 8465:   AE("&Im;");                   break; /* ℑ */
/* Lscr aka Laplacetrf or lagran */
case 8466:   AE("&Lscr;");                 break; /* ℒ */
case 8467:   AE("&ell;");                  break; /* ℓ */
/* Nopf aka naturals */
case 8469:   AE("&Nopf;");                 break; /* ℕ */
case 8470:   AE("&numero;");               break; /* № */
case 8471:   AE("&copysr;");               break; /* ℗ */
/* wp aka weierp */
case 8472:   AE("&wp;");                   break; /* ℘ */
/* Popf aka primes */
case 8473:   AE("&Popf;");                 break; /* ℙ */
/* Qopf aka rationals */
case 8474:   AE("&Qopf;");                 break; /* ℚ */
/* Rscr aka realine */
case 8475:   AE("&Rscr;");                 break; /* ℛ */
/* Re aka Rfr or real or realpart */
case 8476:   AE("&Re;");                   break; /* ℜ */
/* Ropf aka reals */
case 8477:   AE("&Ropf;");                 break; /* ℝ */
case 8478:   AE("&rx;");                   break; /* ℞ */
/* trade aka TRADE */
case 8482:   AE("&trade;");                break; /* ™ */
/* Zopf aka integers */
case 8484:   AE("&Zopf;");                 break; /* ℤ */
case 8487:   AE("&mho;");                  break; /* ℧ */
/* Zfr aka zeetrf */
case 8488:   AE("&Zfr;");                  break; /* ℨ */
case 8489:   AE("&iiota;");                break; /* ℩ */
/* Bscr aka Bernoullis or bernou */
case 8492:   AE("&Bscr;");                 break; /* ℬ */
/* Cfr aka Cayleys */
case 8493:   AE("&Cfr;");                  break; /* ℭ */
case 8495:   AE("&escr;");                 break; /* ℯ */
/* Escr aka expectation */
case 8496:   AE("&Escr;");                 break; /* ℰ */
/* Fscr aka Fouriertrf */
case 8497:   AE("&Fscr;");                 break; /* ℱ */
/* Mscr aka Mellintrf or phmmat */
case 8499:   AE("&Mscr;");                 break; /* ℳ */
/* oscr aka order or orderof */
case 8500:   AE("&oscr;");                 break; /* ℴ */
/* aleph aka alefsym */
case 8501:   AE("&aleph;");                break; /* ℵ */
case 8502:   AE("&beth;");                 break; /* ℶ */
case 8503:   AE("&gimel;");                break; /* ℷ */
case 8504:   AE("&daleth;");               break; /* ℸ */
/* DD aka CapitalDifferentialD */
case 8517:   AE("&DD;");                   break; /* ⅅ */
/* dd aka DifferentialD */
case 8518:   AE("&dd;");                   break; /* ⅆ */
/* ee aka ExponentialE or exponentiale */
case 8519:   AE("&ee;");                   break; /* ⅇ */
/* ii aka ImaginaryI */
case 8520:   AE("&ii;");                   break; /* ⅈ */
case 8531:   AE("&frac13;");               break; /* ⅓ */
case 8532:   AE("&frac23;");               break; /* ⅔ */
case 8533:   AE("&frac15;");               break; /* ⅕ */
case 8534:   AE("&frac25;");               break; /* ⅖ */
case 8535:   AE("&frac35;");               break; /* ⅗ */
case 8536:   AE("&frac45;");               break; /* ⅘ */
case 8537:   AE("&frac16;");               break; /* ⅙ */
case 8538:   AE("&frac56;");               break; /* ⅚ */
case 8539:   AE("&frac18;");               break; /* ⅛ */
case 8540:   AE("&frac38;");               break; /* ⅜ */
case 8541:   AE("&frac58;");               break; /* ⅝ */
case 8542:   AE("&frac78;");               break; /* ⅞ */
/* larr aka LeftArrow or ShortLeftArrow or leftarrow or slarr */
case 8592:   AE("&larr;");                 break; /* ← */
/* uarr aka ShortUpArrow or UpArrow or uparrow */
case 8593:   AE("&uarr;");                 break; /* ↑ */
/* rarr aka RightArrow or ShortRightArrow or rightarrow or srarr */
case 8594:   AE("&rarr;");                 break; /* → */
/* darr aka DownArrow or ShortDownArrow or downarrow */
case 8595:   AE("&darr;");                 break; /* ↓ */
/* harr aka LeftRightArrow or leftrightarrow */
case 8596:   AE("&harr;");                 break; /* ↔ */
/* varr aka UpDownArrow or updownarrow */
case 8597:   AE("&varr;");                 break; /* ↕ */
/* nwarr aka UpperLeftArrow or nwarrow */
case 8598:   AE("&nwarr;");                break; /* ↖ */
/* nearr aka UpperRightArrow or nearrow */
case 8599:   AE("&nearr;");                break; /* ↗ */
/* searr aka LowerRightArrow or searrow */
case 8600:   AE("&searr;");                break; /* ↘ */
/* swarr aka LowerLeftArrow or swarrow */
case 8601:   AE("&swarr;");                break; /* ↙ */
/* nlarr aka nleftarrow */
case 8602:   AE("&nlarr;");                break; /* ↚ */
/* nrarr aka nrightarrow */
case 8603:   AE("&nrarr;");                break; /* ↛ */
case 8605:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&nrarrw;"); MCP;                      /* ↝̸ */
    } else {
        /* rarrw aka rightsquigarrow */
        AE("&rarrw;");                            /* ↝ */
    };                                     break;
/* Larr aka twoheadleftarrow */
case 8606:   AE("&Larr;");                 break; /* ↞ */
case 8607:   AE("&Uarr;");                 break; /* ↟ */
/* Rarr aka twoheadrightarrow */
case 8608:   AE("&Rarr;");                 break; /* ↠ */
case 8609:   AE("&Darr;");                 break; /* ↡ */
/* larrtl aka leftarrowtail */
case 8610:   AE("&larrtl;");               break; /* ↢ */
/* rarrtl aka rightarrowtail */
case 8611:   AE("&rarrtl;");               break; /* ↣ */
/* mapstoleft aka LeftTeeArrow */
case 8612:   AE("&mapstoleft;");           break; /* ↤ */
/* mapstoup aka UpTeeArrow */
case 8613:   AE("&mapstoup;");             break; /* ↥ */
/* map aka RightTeeArrow or mapsto */
case 8614:   AE("&map;");                  break; /* ↦ */
/* mapstodown aka DownTeeArrow */
case 8615:   AE("&mapstodown;");           break; /* ↧ */
/* larrhk aka hookleftarrow */
case 8617:   AE("&larrhk;");               break; /* ↩ */
/* rarrhk aka hookrightarrow */
case 8618:   AE("&rarrhk;");               break; /* ↪ */
/* larrlp aka looparrowleft */
case 8619:   AE("&larrlp;");               break; /* ↫ */
/* rarrlp aka looparrowright */
case 8620:   AE("&rarrlp;");               break; /* ↬ */
/* harrw aka leftrightsquigarrow */
case 8621:   AE("&harrw;");                break; /* ↭ */
/* nharr aka nleftrightarrow */
case 8622:   AE("&nharr;");                break; /* ↮ */
/* lsh aka Lsh */
case 8624:   AE("&lsh;");                  break; /* ↰ */
/* rsh aka Rsh */
case 8625:   AE("&rsh;");                  break; /* ↱ */
case 8626:   AE("&ldsh;");                 break; /* ↲ */
case 8627:   AE("&rdsh;");                 break; /* ↳ */
case 8629:   AE("&crarr;");                break; /* ↵ */
/* cularr aka curvearrowleft */
case 8630:   AE("&cularr;");               break; /* ↶ */
/* curarr aka curvearrowright */
case 8631:   AE("&curarr;");               break; /* ↷ */
/* olarr aka circlearrowleft */
case 8634:   AE("&olarr;");                break; /* ↺ */
/* orarr aka circlearrowright */
case 8635:   AE("&orarr;");                break; /* ↻ */
/* lharu aka LeftVector or leftharpoonup */
case 8636:   AE("&lharu;");                break; /* ↼ */
/* lhard aka DownLeftVector or leftharpoondown */
case 8637:   AE("&lhard;");                break; /* ↽ */
/* uharr aka RightUpVector or upharpoonright */
case 8638:   AE("&uharr;");                break; /* ↾ */
/* uharl aka LeftUpVector or upharpoonleft */
case 8639:   AE("&uharl;");                break; /* ↿ */
/* rharu aka RightVector or rightharpoonup */
case 8640:   AE("&rharu;");                break; /* ⇀ */
/* rhard aka DownRightVector or rightharpoondown */
case 8641:   AE("&rhard;");                break; /* ⇁ */
/* dharr aka RightDownVector or downharpoonright */
case 8642:   AE("&dharr;");                break; /* ⇂ */
/* dharl aka LeftDownVector or downharpoonleft */
case 8643:   AE("&dharl;");                break; /* ⇃ */
/* rlarr aka RightArrowLeftArrow or rightleftarrows */
case 8644:   AE("&rlarr;");                break; /* ⇄ */
/* udarr aka UpArrowDownArrow */
case 8645:   AE("&udarr;");                break; /* ⇅ */
/* lrarr aka LeftArrowRightArrow or leftrightarrows */
case 8646:   AE("&lrarr;");                break; /* ⇆ */
/* llarr aka leftleftarrows */
case 8647:   AE("&llarr;");                break; /* ⇇ */
/* uuarr aka upuparrows */
case 8648:   AE("&uuarr;");                break; /* ⇈ */
/* rrarr aka rightrightarrows */
case 8649:   AE("&rrarr;");                break; /* ⇉ */
/* ddarr aka downdownarrows */
case 8650:   AE("&ddarr;");                break; /* ⇊ */
/* lrhar aka ReverseEquilibrium or leftrightharpoons */
case 8651:   AE("&lrhar;");                break; /* ⇋ */
/* rlhar aka Equilibrium or rightleftharpoons */
case 8652:   AE("&rlhar;");                break; /* ⇌ */
/* nlArr aka nLeftarrow */
case 8653:   AE("&nlArr;");                break; /* ⇍ */
/* nhArr aka nLeftrightarrow */
case 8654:   AE("&nhArr;");                break; /* ⇎ */
/* nrArr aka nRightarrow */
case 8655:   AE("&nrArr;");                break; /* ⇏ */
/* lArr aka DoubleLeftArrow or Leftarrow */
case 8656:   AE("&lArr;");                 break; /* ⇐ */
/* uArr aka DoubleUpArrow or Uparrow */
case 8657:   AE("&uArr;");                 break; /* ⇑ */
/* rArr aka DoubleRightArrow or Implies or Rightarrow */
case 8658:   AE("&rArr;");                 break; /* ⇒ */
/* dArr aka DoubleDownArrow or Downarrow */
case 8659:   AE("&dArr;");                 break; /* ⇓ */
/* iff aka DoubleLeftRightArrow or Leftrightarrow or hArr */
case 8660:   AE("&iff;");                  break; /* ⇔ */
/* vArr aka DoubleUpDownArrow or Updownarrow */
case 8661:   AE("&vArr;");                 break; /* ⇕ */
case 8662:   AE("&nwArr;");                break; /* ⇖ */
case 8663:   AE("&neArr;");                break; /* ⇗ */
case 8664:   AE("&seArr;");                break; /* ⇘ */
case 8665:   AE("&swArr;");                break; /* ⇙ */
/* lAarr aka Lleftarrow */
case 8666:   AE("&lAarr;");                break; /* ⇚ */
/* rAarr aka Rrightarrow */
case 8667:   AE("&rAarr;");                break; /* ⇛ */
case 8669:   AE("&zigrarr;");              break; /* ⇝ */
/* larrb aka LeftArrowBar */
case 8676:   AE("&larrb;");                break; /* ⇤ */
/* rarrb aka RightArrowBar */
case 8677:   AE("&rarrb;");                break; /* ⇥ */
/* duarr aka DownArrowUpArrow */
case 8693:   AE("&duarr;");                break; /* ⇵ */
case 8701:   AE("&loarr;");                break; /* ⇽ */
case 8702:   AE("&roarr;");                break; /* ⇾ */
case 8703:   AE("&hoarr;");                break; /* ⇿ */
/* forall aka ForAll */
case 8704:   AE("&forall;");               break; /* ∀ */
/* comp aka complement */
case 8705:   AE("&comp;");                 break; /* ∁ */
case 8706:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&npart;"); MCP;                       /* ∂̸ */
    } else {
        /* part aka PartialD */
        AE("&part;");                             /* ∂ */
    };                                     break;
/* exist aka Exists */
case 8707:   AE("&exist;");                break; /* ∃ */
/* nexist aka NotExists or nexists */
case 8708:   AE("&nexist;");               break; /* ∄ */
/* empty aka emptyset or emptyv or varnothing */
case 8709:   AE("&empty;");                break; /* ∅ */
/* Del aka nabla */
case 8711:   AE("&Del;");                  break; /* ∇ */
/* in aka Element or isin or isinv */
case 8712:   AE("&in;");                   break; /* ∈ */
/* notin aka NotElement or notinva */
case 8713:   AE("&notin;");                break; /* ∉ */
/* ni aka ReverseElement or SuchThat or niv */
case 8715:   AE("&ni;");                   break; /* ∋ */
/* notni aka NotReverseElement or notniva */
case 8716:   AE("&notni;");                break; /* ∌ */
/* prod aka Product */
case 8719:   AE("&prod;");                 break; /* ∏ */
/* coprod aka Coproduct */
case 8720:   AE("&coprod;");               break; /* ∐ */
/* sum aka Sum */
case 8721:   AE("&sum;");                  break; /* ∑ */
case 8722:   AE("&minus;");                break; /* − */
/* mp aka MinusPlus or mnplus */
case 8723:   AE("&mp;");                   break; /* ∓ */
/* plusdo aka dotplus */
case 8724:   AE("&plusdo;");               break; /* ∔ */
/* setmn aka Backslash or setminus or smallsetminus or ssetmn */
case 8726:   AE("&setmn;");                break; /* ∖ */
case 8727:   AE("&lowast;");               break; /* ∗ */
/* compfn aka SmallCircle */
case 8728:   AE("&compfn;");               break; /* ∘ */
/* Sqrt aka radic */
case 8730:   AE("&Sqrt;");                 break; /* √ */
/* prop aka Proportional or propto or varpropto or vprop */
case 8733:   AE("&prop;");                 break; /* ∝ */
case 8734:   AE("&infin;");                break; /* ∞ */
case 8735:   AE("&angrt;");                break; /* ∟ */
case 8736:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nang;"); MCP;                        /* ∠⃒ */
    } else {
        /* ang aka angle */
        AE("&ang;");                              /* ∠ */
    };                                     break;
/* angmsd aka measuredangle */
case 8737:   AE("&angmsd;");               break; /* ∡ */
case 8738:   AE("&angsph;");               break; /* ∢ */
/* mid aka VerticalBar or shortmid or smid */
case 8739:   AE("&mid;");                  break; /* ∣ */
/* nmid aka NotVerticalBar or nshortmid or nsmid */
case 8740:   AE("&nmid;");                 break; /* ∤ */
/* par aka DoubleVerticalBar or parallel or shortparallel or spar */
case 8741:   AE("&par;");                  break; /* ∥ */
/* npar aka NotDoubleVerticalBar or nparallel or nshortparallel or nspar */
case 8742:   AE("&npar;");                 break; /* ∦ */
/* and aka wedge */
case 8743:   AE("&and;");                  break; /* ∧ */
/* or aka vee */
case 8744:   AE("&or;");                   break; /* ∨ */
case 8745:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&caps;"); MCP;                        /* ∩︀ */
    } else {
        AE("&cap;");                              /* ∩ */
    };                                     break;
case 8746:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&cups;"); MCP;                        /* ∪︀ */
    } else {
        AE("&cup;");                              /* ∪ */
    };                                     break;
/* int aka Integral */
case 8747:   AE("&int;");                  break; /* ∫ */
case 8748:   AE("&Int;");                  break; /* ∬ */
/* tint aka iiint */
case 8749:   AE("&tint;");                 break; /* ∭ */
/* oint aka ContourIntegral or conint */
case 8750:   AE("&oint;");                 break; /* ∮ */
/* Conint aka DoubleContourIntegral */
case 8751:   AE("&Conint;");               break; /* ∯ */
case 8752:   AE("&Cconint;");              break; /* ∰ */
case 8753:   AE("&cwint;");                break; /* ∱ */
/* cwconint aka ClockwiseContourIntegral */
case 8754:   AE("&cwconint;");             break; /* ∲ */
/* awconint aka CounterClockwiseContourIntegral */
case 8755:   AE("&awconint;");             break; /* ∳ */
/* there4 aka Therefore or therefore */
case 8756:   AE("&there4;");               break; /* ∴ */
/* becaus aka Because or because */
case 8757:   AE("&becaus;");               break; /* ∵ */
case 8758:   AE("&ratio;");                break; /* ∶ */
/* Colon aka Proportion */
case 8759:   AE("&Colon;");                break; /* ∷ */
/* minusd aka dotminus */
case 8760:   AE("&minusd;");               break; /* ∸ */
case 8762:   AE("&mDDot;");                break; /* ∺ */
case 8763:   AE("&homtht;");               break; /* ∻ */
case 8764:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvsim;"); MCP;                       /* ∼⃒ */
    } else {
        /* sim aka Tilde or thicksim or thksim */
        AE("&sim;");                              /* ∼ */
    };                                     break;
case 8765:   TWOCPE;
    if (clen2 && uniChar2 == 817) { 
        AE("&race;"); MCP;                        /* ∽̱ */
    } else {
        /* bsim aka backsim */
        AE("&bsim;");                             /* ∽ */
    };                                     break;
case 8766:   TWOCPE;
    if (clen2 && uniChar2 == 819) { 
        AE("&acE;"); MCP;                         /* ∾̳ */
    } else {
        /* ac aka mstpos */
        AE("&ac;");                               /* ∾ */
    };                                     break;
case 8767:   AE("&acd;");                  break; /* ∿ */
/* wr aka VerticalTilde or wreath */
case 8768:   AE("&wr;");                   break; /* ≀ */
/* nsim aka NotTilde */
case 8769:   AE("&nsim;");                 break; /* ≁ */
case 8770:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* esim aka NotEqualTilde */
        AE("&nesim;"); MCP;                       /* ≂̸ */
    } else {
        /* esim aka EqualTilde or eqsim */
        AE("&esim;");                             /* ≂ */
    };                                     break;
/* sime aka TildeEqual or simeq */
case 8771:   AE("&sime;");                 break; /* ≃ */
/* nsime aka NotTildeEqual or nsimeq */
case 8772:   AE("&nsime;");                break; /* ≄ */
/* cong aka TildeFullEqual */
case 8773:   AE("&cong;");                 break; /* ≅ */
case 8774:   AE("&simne;");                break; /* ≆ */
/* ncong aka NotTildeFullEqual */
case 8775:   AE("&ncong;");                break; /* ≇ */
/* ap aka TildeTilde or approx or asymp or thickapprox or thkap */
case 8776:   AE("&ap;");                   break; /* ≈ */
/* nap aka NotTildeTilde or napprox */
case 8777:   AE("&nap;");                  break; /* ≉ */
/* ape aka approxeq */
case 8778:   AE("&ape;");                  break; /* ≊ */
case 8779:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&napid;"); MCP;                       /* ≋̸ */
    } else {
        AE("&apid;");                             /* ≋ */
    };                                     break;
/* bcong aka backcong */
case 8780:   AE("&bcong;");                break; /* ≌ */
case 8781:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvap;"); MCP;                        /* ≍⃒ */
    } else {
        /* CupCap aka asympeq */
        AE("&CupCap;");                           /* ≍ */
    };                                     break;
case 8782:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* bump aka NotHumpDownHump */
        AE("&nbump;"); MCP;                       /* ≎̸ */
    } else {
        /* bump aka Bumpeq or HumpDownHump */
        AE("&bump;");                             /* ≎ */
    };                                     break;
case 8783:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* bumpe aka NotHumpEqual */
        AE("&nbumpe;"); MCP;                      /* ≏̸ */
    } else {
        /* bumpe aka HumpEqual or bumpeq */
        AE("&bumpe;");                            /* ≏ */
    };                                     break;
case 8784:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&nedot;"); MCP;                       /* ≐̸ */
    } else {
        /* doteq aka DotEqual or esdot */
        AE("&doteq;");                            /* ≐ */
    };                                     break;
/* eDot aka doteqdot */
case 8785:   AE("&eDot;");                 break; /* ≑ */
/* efDot aka fallingdotseq */
case 8786:   AE("&efDot;");                break; /* ≒ */
/* erDot aka risingdotseq */
case 8787:   AE("&erDot;");                break; /* ≓ */
/* Assign aka colone or coloneq */
case 8788:   AE("&Assign;");               break; /* ≔ */
/* ecolon aka eqcolon */
case 8789:   AE("&ecolon;");               break; /* ≕ */
/* ecir aka eqcirc */
case 8790:   AE("&ecir;");                 break; /* ≖ */
/* cire aka circeq */
case 8791:   AE("&cire;");                 break; /* ≗ */
case 8793:   AE("&wedgeq;");               break; /* ≙ */
case 8794:   AE("&veeeq;");                break; /* ≚ */
/* trie aka triangleq */
case 8796:   AE("&trie;");                 break; /* ≜ */
/* equest aka questeq */
case 8799:   AE("&equest;");               break; /* ≟ */
/* ne aka NotEqual */
case 8800:   AE("&ne;");                   break; /* ≠ */
case 8801:   TWOCPE;
    if (clen2 && uniChar2 == 8421) { 
        AE("&bnequiv;"); MCP;                     /* ≡⃥ */
    } else {
        /* equiv aka Congruent */
        AE("&equiv;");                            /* ≡ */
    };                                     break;
/* nequiv aka NotCongruent */
case 8802:   AE("&nequiv;");               break; /* ≢ */
case 8804:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvle;"); MCP;                        /* ≤⃒ */
    } else {
        /* le aka leq */
        AE("&le;");                               /* ≤ */
    };                                     break;
case 8805:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvge;"); MCP;                        /* ≥⃒ */
    } else {
        /* ge aka GreaterEqual or geq */
        AE("&ge;");                               /* ≥ */
    };                                     break;
case 8806:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* lE aka nleqq */
        AE("&nlE;"); MCP;                         /* ≦̸ */
    } else {
        /* lE aka LessFullEqual or leqq */
        AE("&lE;");                               /* ≦ */
    };                                     break;
case 8807:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* gE aka NotGreaterFullEqual or ngeqq */
        AE("&ngE;"); MCP;                         /* ≧̸ */
    } else {
        /* gE aka GreaterFullEqual or geqq */
        AE("&gE;");                               /* ≧ */
    };                                     break;
case 8808:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        /* lnE aka lvertneqq */
        AE("&lvnE;"); MCP;                        /* ≨︀ */
    } else {
        /* lnE aka lneqq */
        AE("&lnE;");                              /* ≨ */
    };                                     break;
case 8809:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        /* gnE aka gvertneqq */
        AE("&gvnE;"); MCP;                        /* ≩︀ */
    } else {
        /* gnE aka gneqq */
        AE("&gnE;");                              /* ≩ */
    };                                     break;
case 8810:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* nLtv aka NotLessLess */
         AE("&nLtv;"); MCP;                         /* ≪̸ */
    } else if (clen2 && uniChar2 == 8402) {
         AE("&nLt;"); MCP;                          /* ≪⃒ */
    } else {
        /* ll aka Lt or NestedLessLess */
        AE("&ll;");                               /* ≪ */
    };                                     break;
case 8811:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* nGtv aka NotGreaterGreater */
         AE("&nGtv;"); MCP;                         /* ≫̸ */
    } else if (clen2 && uniChar2 == 8402) {
         AE("&nGt;"); MCP;                          /* ≫⃒ */
    } else {
        /* gg aka Gt or NestedGreaterGreater */
        AE("&gg;");                               /* ≫ */
    };                                     break;
/* twixt aka between */
case 8812:   AE("&twixt;");                break; /* ≬ */
case 8813:   AE("&NotCupCap;");            break; /* ≭ */
/* nlt aka NotLess or nless */
case 8814:   AE("&nlt;");                  break; /* ≮ */
/* ngt aka NotGreater or ngtr */
case 8815:   AE("&ngt;");                  break; /* ≯ */
/* nle aka NotLessEqual or nleq */
case 8816:   AE("&nle;");                  break; /* ≰ */
/* nge aka NotGreaterEqual or ngeq */
case 8817:   AE("&nge;");                  break; /* ≱ */
/* lsim aka LessTilde or lesssim */
case 8818:   AE("&lsim;");                 break; /* ≲ */
/* gsim aka GreaterTilde or gtrsim */
case 8819:   AE("&gsim;");                 break; /* ≳ */
/* nlsim aka NotLessTilde */
case 8820:   AE("&nlsim;");                break; /* ≴ */
/* ngsim aka NotGreaterTilde */
case 8821:   AE("&ngsim;");                break; /* ≵ */
/* lg aka LessGreater or lessgtr */
case 8822:   AE("&lg;");                   break; /* ≶ */
/* gl aka GreaterLess or gtrless */
case 8823:   AE("&gl;");                   break; /* ≷ */
/* ntlg aka NotLessGreater */
case 8824:   AE("&ntlg;");                 break; /* ≸ */
/* ntgl aka NotGreaterLess */
case 8825:   AE("&ntgl;");                 break; /* ≹ */
/* pr aka Precedes or prec */
case 8826:   AE("&pr;");                   break; /* ≺ */
/* sc aka Succeeds or succ */
case 8827:   AE("&sc;");                   break; /* ≻ */
/* prcue aka PrecedesSlantEqual or preccurlyeq */
case 8828:   AE("&prcue;");                break; /* ≼ */
/* sccue aka SucceedsSlantEqual or succcurlyeq */
case 8829:   AE("&sccue;");                break; /* ≽ */
/* prsim aka PrecedesTilde or precsim */
case 8830:   AE("&prsim;");                break; /* ≾ */
case 8831:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotSucceedsTilde;"); MCP;            /* ≿̸ */
    } else {
        /* scsim aka SucceedsTilde or succsim */
        AE("&scsim;");                            /* ≿ */
    };                                     break;
/* npr aka NotPrecedes or nprec */
case 8832:   AE("&npr;");                  break; /* ⊀ */
/* nsc aka NotSucceeds or nsucc */
case 8833:   AE("&nsc;");                  break; /* ⊁ */
case 8834:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        /* sub aka NotSubset or nsubset */
        AE("&vnsub;"); MCP;                       /* ⊂⃒ */
    } else {
        /* sub aka subset */
        AE("&sub;");                              /* ⊂ */
    };                                     break;
case 8835:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        /* sup aka NotSuperset or nsupset */
        AE("&vnsup;"); MCP;                       /* ⊃⃒ */
    } else {
        /* sup aka Superset or supset */
        AE("&sup;");                              /* ⊃ */
    };                                     break;
case 8836:   AE("&nsub;");                 break; /* ⊄ */
case 8837:   AE("&nsup;");                 break; /* ⊅ */
/* sube aka SubsetEqual or subseteq */
case 8838:   AE("&sube;");                 break; /* ⊆ */
/* supe aka SupersetEqual or supseteq */
case 8839:   AE("&supe;");                 break; /* ⊇ */
/* nsube aka NotSubsetEqual or nsubseteq */
case 8840:   AE("&nsube;");                break; /* ⊈ */
/* nsupe aka NotSupersetEqual or nsupseteq */
case 8841:   AE("&nsupe;");                break; /* ⊉ */
case 8842:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        /* subne aka varsubsetneq */
        AE("&vsubne;"); MCP;                      /* ⊊︀ */
    } else {
        /* subne aka subsetneq */
        AE("&subne;");                            /* ⊊ */
    };                                     break;
case 8843:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        /* supne aka varsupsetneq */
        AE("&vsupne;"); MCP;                      /* ⊋︀ */
    } else {
        /* supne aka supsetneq */
        AE("&supne;");                            /* ⊋ */
    };                                     break;
case 8845:   AE("&cupdot;");               break; /* ⊍ */
/* uplus aka UnionPlus */
case 8846:   AE("&uplus;");                break; /* ⊎ */
case 8847:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotSquareSubset;"); MCP;             /* ⊏̸ */
    } else {
        /* sqsub aka SquareSubset or sqsubset */
        AE("&sqsub;");                            /* ⊏ */
    };                                     break;
case 8848:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotSquareSuperset;"); MCP;           /* ⊐̸ */
    } else {
        /* sqsup aka SquareSuperset or sqsupset */
        AE("&sqsup;");                            /* ⊐ */
    };                                     break;
/* sqsube aka SquareSubsetEqual or sqsubseteq */
case 8849:   AE("&sqsube;");               break; /* ⊑ */
/* sqsupe aka SquareSupersetEqual or sqsupseteq */
case 8850:   AE("&sqsupe;");               break; /* ⊒ */
case 8851:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&sqcaps;"); MCP;                      /* ⊓︀ */
    } else {
        /* sqcap aka SquareIntersection */
        AE("&sqcap;");                            /* ⊓ */
    };                                     break;
case 8852:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&sqcups;"); MCP;                      /* ⊔︀ */
    } else {
        /* sqcup aka SquareUnion */
        AE("&sqcup;");                            /* ⊔ */
    };                                     break;
/* oplus aka CirclePlus */
case 8853:   AE("&oplus;");                break; /* ⊕ */
/* ominus aka CircleMinus */
case 8854:   AE("&ominus;");               break; /* ⊖ */
/* otimes aka CircleTimes */
case 8855:   AE("&otimes;");               break; /* ⊗ */
case 8856:   AE("&osol;");                 break; /* ⊘ */
/* odot aka CircleDot */
case 8857:   AE("&odot;");                 break; /* ⊙ */
/* ocir aka circledcirc */
case 8858:   AE("&ocir;");                 break; /* ⊚ */
/* oast aka circledast */
case 8859:   AE("&oast;");                 break; /* ⊛ */
/* odash aka circleddash */
case 8861:   AE("&odash;");                break; /* ⊝ */
/* plusb aka boxplus */
case 8862:   AE("&plusb;");                break; /* ⊞ */
/* minusb aka boxminus */
case 8863:   AE("&minusb;");               break; /* ⊟ */
/* timesb aka boxtimes */
case 8864:   AE("&timesb;");               break; /* ⊠ */
/* sdotb aka dotsquare */
case 8865:   AE("&sdotb;");                break; /* ⊡ */
/* vdash aka RightTee */
case 8866:   AE("&vdash;");                break; /* ⊢ */
/* dashv aka LeftTee */
case 8867:   AE("&dashv;");                break; /* ⊣ */
/* top aka DownTee */
case 8868:   AE("&top;");                  break; /* ⊤ */
/* bot aka UpTee or bottom or perp */
case 8869:   AE("&bot;");                  break; /* ⊥ */
case 8871:   AE("&models;");               break; /* ⊧ */
/* vDash aka DoubleRightTee */
case 8872:   AE("&vDash;");                break; /* ⊨ */
case 8873:   AE("&Vdash;");                break; /* ⊩ */
case 8874:   AE("&Vvdash;");               break; /* ⊪ */
case 8875:   AE("&VDash;");                break; /* ⊫ */
case 8876:   AE("&nvdash;");               break; /* ⊬ */
case 8877:   AE("&nvDash;");               break; /* ⊭ */
case 8878:   AE("&nVdash;");               break; /* ⊮ */
case 8879:   AE("&nVDash;");               break; /* ⊯ */
case 8880:   AE("&prurel;");               break; /* ⊰ */
/* vltri aka LeftTriangle or vartriangleleft */
case 8882:   AE("&vltri;");                break; /* ⊲ */
/* vrtri aka RightTriangle or vartriangleright */
case 8883:   AE("&vrtri;");                break; /* ⊳ */
case 8884:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvltrie;"); MCP;                     /* ⊴⃒ */
    } else {
        /* ltrie aka LeftTriangleEqual or trianglelefteq */
        AE("&ltrie;");                            /* ⊴ */
    };                                     break;
case 8885:   TWOCPE;
    if (clen2 && uniChar2 == 8402) { 
        AE("&nvrtrie;"); MCP;                     /* ⊵⃒ */
    } else {
        /* rtrie aka RightTriangleEqual or trianglerighteq */
        AE("&rtrie;");                            /* ⊵ */
    };                                     break;
case 8886:   AE("&origof;");               break; /* ⊶ */
case 8887:   AE("&imof;");                 break; /* ⊷ */
/* mumap aka multimap */
case 8888:   AE("&mumap;");                break; /* ⊸ */
case 8889:   AE("&hercon;");               break; /* ⊹ */
/* intcal aka intercal */
case 8890:   AE("&intcal;");               break; /* ⊺ */
case 8891:   AE("&veebar;");               break; /* ⊻ */
case 8893:   AE("&barvee;");               break; /* ⊽ */
case 8894:   AE("&angrtvb;");              break; /* ⊾ */
case 8895:   AE("&lrtri;");                break; /* ⊿ */
/* Wedge aka bigwedge or xwedge */
case 8896:   AE("&Wedge;");                break; /* ⋀ */
/* Vee aka bigvee or xvee */
case 8897:   AE("&Vee;");                  break; /* ⋁ */
/* xcap aka Intersection or bigcap */
case 8898:   AE("&xcap;");                 break; /* ⋂ */
/* xcup aka Union or bigcup */
case 8899:   AE("&xcup;");                 break; /* ⋃ */
/* diam aka Diamond or diamond */
case 8900:   AE("&diam;");                 break; /* ⋄ */
case 8901:   AE("&sdot;");                 break; /* ⋅ */
/* Star aka sstarf */
case 8902:   AE("&Star;");                 break; /* ⋆ */
/* divonx aka divideontimes */
case 8903:   AE("&divonx;");               break; /* ⋇ */
case 8904:   AE("&bowtie;");               break; /* ⋈ */
case 8905:   AE("&ltimes;");               break; /* ⋉ */
case 8906:   AE("&rtimes;");               break; /* ⋊ */
/* lthree aka leftthreetimes */
case 8907:   AE("&lthree;");               break; /* ⋋ */
/* rthree aka rightthreetimes */
case 8908:   AE("&rthree;");               break; /* ⋌ */
/* bsime aka backsimeq */
case 8909:   AE("&bsime;");                break; /* ⋍ */
/* cuvee aka curlyvee */
case 8910:   AE("&cuvee;");                break; /* ⋎ */
/* cuwed aka curlywedge */
case 8911:   AE("&cuwed;");                break; /* ⋏ */
/* Sub aka Subset */
case 8912:   AE("&Sub;");                  break; /* ⋐ */
/* Sup aka Supset */
case 8913:   AE("&Sup;");                  break; /* ⋑ */
case 8914:   AE("&Cap;");                  break; /* ⋒ */
case 8915:   AE("&Cup;");                  break; /* ⋓ */
/* fork aka pitchfork */
case 8916:   AE("&fork;");                 break; /* ⋔ */
case 8917:   AE("&epar;");                 break; /* ⋕ */
/* ltdot aka lessdot */
case 8918:   AE("&ltdot;");                break; /* ⋖ */
/* gtdot aka gtrdot */
case 8919:   AE("&gtdot;");                break; /* ⋗ */
case 8920:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&nLl;"); MCP;                         /* ⋘̸ */
    } else {
        AE("&Ll;");                               /* ⋘ */
    };                                     break;
case 8921:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&nGg;"); MCP;                         /* ⋙̸ */
    } else {
        /* Gg aka ggg */
        AE("&Gg;");                               /* ⋙ */
    };                                     break;
case 8922:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&lesg;"); MCP;                        /* ⋚︀ */
    } else {
        /* leg aka LessEqualGreater or lesseqgtr */
        AE("&leg;");                              /* ⋚ */
    };                                     break;
case 8923:   TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&gesl;"); MCP;                        /* ⋛︀ */
    } else {
        /* gel aka GreaterEqualLess or gtreqless */
        AE("&gel;");                              /* ⋛ */
    };                                     break;
/* cuepr aka curlyeqprec */
case 8926:   AE("&cuepr;");                break; /* ⋞ */
/* cuesc aka curlyeqsucc */
case 8927:   AE("&cuesc;");                break; /* ⋟ */
/* nprcue aka NotPrecedesSlantEqual */
case 8928:   AE("&nprcue;");               break; /* ⋠ */
/* nsccue aka NotSucceedsSlantEqual */
case 8929:   AE("&nsccue;");               break; /* ⋡ */
/* nsqsube aka NotSquareSubsetEqual */
case 8930:   AE("&nsqsube;");              break; /* ⋢ */
/* nsqsupe aka NotSquareSupersetEqual */
case 8931:   AE("&nsqsupe;");              break; /* ⋣ */
case 8934:   AE("&lnsim;");                break; /* ⋦ */
case 8935:   AE("&gnsim;");                break; /* ⋧ */
/* prnsim aka precnsim */
case 8936:   AE("&prnsim;");               break; /* ⋨ */
/* scnsim aka succnsim */
case 8937:   AE("&scnsim;");               break; /* ⋩ */
/* nltri aka NotLeftTriangle or ntriangleleft */
case 8938:   AE("&nltri;");                break; /* ⋪ */
/* nrtri aka NotRightTriangle or ntriangleright */
case 8939:   AE("&nrtri;");                break; /* ⋫ */
/* nltrie aka NotLeftTriangleEqual or ntrianglelefteq */
case 8940:   AE("&nltrie;");               break; /* ⋬ */
/* nrtrie aka NotRightTriangleEqual or ntrianglerighteq */
case 8941:   AE("&nrtrie;");               break; /* ⋭ */
case 8942:   AE("&vellip;");               break; /* ⋮ */
case 8943:   AE("&ctdot;");                break; /* ⋯ */
case 8944:   AE("&utdot;");                break; /* ⋰ */
case 8945:   AE("&dtdot;");                break; /* ⋱ */
case 8946:   AE("&disin;");                break; /* ⋲ */
case 8947:   AE("&isinsv;");               break; /* ⋳ */
case 8948:   AE("&isins;");                break; /* ⋴ */
case 8949:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&notindot;"); MCP;                    /* ⋵̸ */
    } else {
        AE("&isindot;");                          /* ⋵ */
    };                                     break;
case 8950:   AE("&notinvc;");              break; /* ⋶ */
case 8951:   AE("&notinvb;");              break; /* ⋷ */
case 8953:   TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&notinE;"); MCP;                      /* ⋹̸ */
    } else {
        AE("&isinE;");                            /* ⋹ */
    };                                     break;
case 8954:   AE("&nisd;");                 break; /* ⋺ */
case 8955:   AE("&xnis;");                 break; /* ⋻ */
case 8956:   AE("&nis;");                  break; /* ⋼ */
case 8957:   AE("&notnivc;");              break; /* ⋽ */
case 8958:   AE("&notnivb;");              break; /* ⋾ */
/* barwed aka barwedge */
case 8965:   AE("&barwed;");               break; /* ⌅ */
/* Barwed aka doublebarwedge */
case 8966:   AE("&Barwed;");               break; /* ⌆ */
/* lceil aka LeftCeiling */
case 8968:   AE("&lceil;");                break; /* ⌈ */
/* rceil aka RightCeiling */
case 8969:   AE("&rceil;");                break; /* ⌉ */
/* lfloor aka LeftFloor */
case 8970:   AE("&lfloor;");               break; /* ⌊ */
/* rfloor aka RightFloor */
case 8971:   AE("&rfloor;");               break; /* ⌋ */
case 8972:   AE("&drcrop;");               break; /* ⌌ */
case 8973:   AE("&dlcrop;");               break; /* ⌍ */
case 8974:   AE("&urcrop;");               break; /* ⌎ */
case 8975:   AE("&ulcrop;");               break; /* ⌏ */
case 8976:   AE("&bnot;");                 break; /* ⌐ */
case 8978:   AE("&profline;");             break; /* ⌒ */
case 8979:   AE("&profsurf;");             break; /* ⌓ */
case 8981:   AE("&telrec;");               break; /* ⌕ */
case 8982:   AE("&target;");               break; /* ⌖ */
/* ulcorn aka ulcorner */
case 8988:   AE("&ulcorn;");               break; /* ⌜ */
/* urcorn aka urcorner */
case 8989:   AE("&urcorn;");               break; /* ⌝ */
/* dlcorn aka llcorner */
case 8990:   AE("&dlcorn;");               break; /* ⌞ */
/* drcorn aka lrcorner */
case 8991:   AE("&drcorn;");               break; /* ⌟ */
/* frown aka sfrown */
case 8994:   AE("&frown;");                break; /* ⌢ */
/* smile aka ssmile */
case 8995:   AE("&smile;");                break; /* ⌣ */
case 9005:   AE("&cylcty;");               break; /* ⌭ */
case 9006:   AE("&profalar;");             break; /* ⌮ */
case 9014:   AE("&topbot;");               break; /* ⌶ */
case 9021:   AE("&ovbar;");                break; /* ⌽ */
case 9023:   AE("&solbar;");               break; /* ⌿ */
case 9084:   AE("&angzarr;");              break; /* ⍼ */
/* lmoust aka lmoustache */
case 9136:   AE("&lmoust;");               break; /* ⎰ */
/* rmoust aka rmoustache */
case 9137:   AE("&rmoust;");               break; /* ⎱ */
/* tbrk aka OverBracket */
case 9140:   AE("&tbrk;");                 break; /* ⎴ */
/* bbrk aka UnderBracket */
case 9141:   AE("&bbrk;");                 break; /* ⎵ */
case 9142:   AE("&bbrktbrk;");             break; /* ⎶ */
case 9180:   AE("&OverParenthesis;");      break; /* ⏜ */
case 9181:   AE("&UnderParenthesis;");     break; /* ⏝ */
case 9182:   AE("&OverBrace;");            break; /* ⏞ */
case 9183:   AE("&UnderBrace;");           break; /* ⏟ */
case 9186:   AE("&trpezium;");             break; /* ⏢ */
case 9191:   AE("&elinters;");             break; /* ⏧ */
case 9251:   AE("&blank;");                break; /* ␣ */
/* oS aka circledS */
case 9416:   AE("&oS;");                   break; /* Ⓢ */
/* boxh aka HorizontalLine */
case 9472:   AE("&boxh;");                 break; /* ─ */
case 9474:   AE("&boxv;");                 break; /* │ */
case 9484:   AE("&boxdr;");                break; /* ┌ */
case 9488:   AE("&boxdl;");                break; /* ┐ */
case 9492:   AE("&boxur;");                break; /* └ */
case 9496:   AE("&boxul;");                break; /* ┘ */
case 9500:   AE("&boxvr;");                break; /* ├ */
case 9508:   AE("&boxvl;");                break; /* ┤ */
case 9516:   AE("&boxhd;");                break; /* ┬ */
case 9524:   AE("&boxhu;");                break; /* ┴ */
case 9532:   AE("&boxvh;");                break; /* ┼ */
case 9552:   AE("&boxH;");                 break; /* ═ */
case 9553:   AE("&boxV;");                 break; /* ║ */
case 9554:   AE("&boxdR;");                break; /* ╒ */
case 9555:   AE("&boxDr;");                break; /* ╓ */
case 9556:   AE("&boxDR;");                break; /* ╔ */
case 9557:   AE("&boxdL;");                break; /* ╕ */
case 9558:   AE("&boxDl;");                break; /* ╖ */
case 9559:   AE("&boxDL;");                break; /* ╗ */
case 9560:   AE("&boxuR;");                break; /* ╘ */
case 9561:   AE("&boxUr;");                break; /* ╙ */
case 9562:   AE("&boxUR;");                break; /* ╚ */
case 9563:   AE("&boxuL;");                break; /* ╛ */
case 9564:   AE("&boxUl;");                break; /* ╜ */
case 9565:   AE("&boxUL;");                break; /* ╝ */
case 9566:   AE("&boxvR;");                break; /* ╞ */
case 9567:   AE("&boxVr;");                break; /* ╟ */
case 9568:   AE("&boxVR;");                break; /* ╠ */
case 9569:   AE("&boxvL;");                break; /* ╡ */
case 9570:   AE("&boxVl;");                break; /* ╢ */
case 9571:   AE("&boxVL;");                break; /* ╣ */
case 9572:   AE("&boxHd;");                break; /* ╤ */
case 9573:   AE("&boxhD;");                break; /* ╥ */
case 9574:   AE("&boxHD;");                break; /* ╦ */
case 9575:   AE("&boxHu;");                break; /* ╧ */
case 9576:   AE("&boxhU;");                break; /* ╨ */
case 9577:   AE("&boxHU;");                break; /* ╩ */
case 9578:   AE("&boxvH;");                break; /* ╪ */
case 9579:   AE("&boxVh;");                break; /* ╫ */
case 9580:   AE("&boxVH;");                break; /* ╬ */
case 9600:   AE("&uhblk;");                break; /* ▀ */
case 9604:   AE("&lhblk;");                break; /* ▄ */
case 9608:   AE("&block;");                break; /* █ */
case 9617:   AE("&blk14;");                break; /* ░ */
case 9618:   AE("&blk12;");                break; /* ▒ */
case 9619:   AE("&blk34;");                break; /* ▓ */
/* squ aka Square or square */
case 9633:   AE("&squ;");                  break; /* □ */
/* squf aka FilledVerySmallSquare or blacksquare or squarf */
case 9642:   AE("&squf;");                 break; /* ▪ */
case 9643:   AE("&EmptyVerySmallSquare;"); break; /* ▫ */
case 9645:   AE("&rect;");                 break; /* ▭ */
case 9646:   AE("&marker;");               break; /* ▮ */
case 9649:   AE("&fltns;");                break; /* ▱ */
/* xutri aka bigtriangleup */
case 9651:   AE("&xutri;");                break; /* △ */
/* utrif aka blacktriangle */
case 9652:   AE("&utrif;");                break; /* ▴ */
/* utri aka triangle */
case 9653:   AE("&utri;");                 break; /* ▵ */
/* rtrif aka blacktriangleright */
case 9656:   AE("&rtrif;");                break; /* ▸ */
/* rtri aka triangleright */
case 9657:   AE("&rtri;");                 break; /* ▹ */
/* xdtri aka bigtriangledown */
case 9661:   AE("&xdtri;");                break; /* ▽ */
/* dtrif aka blacktriangledown */
case 9662:   AE("&dtrif;");                break; /* ▾ */
/* dtri aka triangledown */
case 9663:   AE("&dtri;");                 break; /* ▿ */
/* ltrif aka blacktriangleleft */
case 9666:   AE("&ltrif;");                break; /* ◂ */
/* ltri aka triangleleft */
case 9667:   AE("&ltri;");                 break; /* ◃ */
/* loz aka lozenge */
case 9674:   AE("&loz;");                  break; /* ◊ */
case 9675:   AE("&cir;");                  break; /* ○ */
case 9708:   AE("&tridot;");               break; /* ◬ */
/* xcirc aka bigcirc */
case 9711:   AE("&xcirc;");                break; /* ◯ */
case 9720:   AE("&ultri;");                break; /* ◸ */
case 9721:   AE("&urtri;");                break; /* ◹ */
case 9722:   AE("&lltri;");                break; /* ◺ */
case 9723:   AE("&EmptySmallSquare;");     break; /* ◻ */
case 9724:   AE("&FilledSmallSquare;");    break; /* ◼ */
/* starf aka bigstar */
case 9733:   AE("&starf;");                break; /* ★ */
case 9734:   AE("&star;");                 break; /* ☆ */
case 9742:   AE("&phone;");                break; /* ☎ */
case 9792:   AE("&female;");               break; /* ♀ */
case 9794:   AE("&male;");                 break; /* ♂ */
/* spades aka spadesuit */
case 9824:   AE("&spades;");               break; /* ♠ */
/* clubs aka clubsuit */
case 9827:   AE("&clubs;");                break; /* ♣ */
/* hearts aka heartsuit */
case 9829:   AE("&hearts;");               break; /* ♥ */
/* diams aka diamondsuit */
case 9830:   AE("&diams;");                break; /* ♦ */
case 9834:   AE("&sung;");                 break; /* ♪ */
case 9837:   AE("&flat;");                 break; /* ♭ */
/* natur aka natural */
case 9838:   AE("&natur;");                break; /* ♮ */
case 9839:   AE("&sharp;");                break; /* ♯ */
/* check aka checkmark */
case 10003:  AE("&check;");                break; /* ✓ */
case 10007:  AE("&cross;");                break; /* ✗ */
/* malt aka maltese */
case 10016:  AE("&malt;");                 break; /* ✠ */
case 10038:  AE("&sext;");                 break; /* ✶ */
case 10072:  AE("&VerticalSeparator;");    break; /* ❘ */
case 10098:  AE("&lbbrk;");                break; /* ❲ */
case 10099:  AE("&rbbrk;");                break; /* ❳ */
case 10184:  AE("&bsolhsub;");             break; /* ⟈ */
case 10185:  AE("&suphsol;");              break; /* ⟉ */
/* lobrk aka LeftDoubleBracket */
case 10214:  AE("&lobrk;");                break; /* ⟦ */
/* robrk aka RightDoubleBracket */
case 10215:  AE("&robrk;");                break; /* ⟧ */
/* lang aka LeftAngleBracket or langle */
case 10216:  AE("&lang;");                 break; /* ⟨ */
/* rang aka RightAngleBracket or rangle */
case 10217:  AE("&rang;");                 break; /* ⟩ */
case 10218:  AE("&Lang;");                 break; /* ⟪ */
case 10219:  AE("&Rang;");                 break; /* ⟫ */
case 10220:  AE("&loang;");                break; /* ⟬ */
case 10221:  AE("&roang;");                break; /* ⟭ */
/* xlarr aka LongLeftArrow or longleftarrow */
case 10229:  AE("&xlarr;");                break; /* ⟵ */
/* xrarr aka LongRightArrow or longrightarrow */
case 10230:  AE("&xrarr;");                break; /* ⟶ */
/* xharr aka LongLeftRightArrow or longleftrightarrow */
case 10231:  AE("&xharr;");                break; /* ⟷ */
/* xlArr aka DoubleLongLeftArrow or Longleftarrow */
case 10232:  AE("&xlArr;");                break; /* ⟸ */
/* xrArr aka DoubleLongRightArrow or Longrightarrow */
case 10233:  AE("&xrArr;");                break; /* ⟹ */
/* xhArr aka DoubleLongLeftRightArrow or Longleftrightarrow */
case 10234:  AE("&xhArr;");                break; /* ⟺ */
/* xmap aka longmapsto */
case 10236:  AE("&xmap;");                 break; /* ⟼ */
case 10239:  AE("&dzigrarr;");             break; /* ⟿ */
case 10498:  AE("&nvlArr;");               break; /* ⤂ */
case 10499:  AE("&nvrArr;");               break; /* ⤃ */
case 10500:  AE("&nvHarr;");               break; /* ⤄ */
case 10501:  AE("&Map;");                  break; /* ⤅ */
case 10508:  AE("&lbarr;");                break; /* ⤌ */
/* rbarr aka bkarow */
case 10509:  AE("&rbarr;");                break; /* ⤍ */
case 10510:  AE("&lBarr;");                break; /* ⤎ */
/* rBarr aka dbkarow */
case 10511:  AE("&rBarr;");                break; /* ⤏ */
/* RBarr aka drbkarow */
case 10512:  AE("&RBarr;");                break; /* ⤐ */
case 10513:  AE("&DDotrahd;");             break; /* ⤑ */
case 10514:  AE("&UpArrowBar;");           break; /* ⤒ */
case 10515:  AE("&DownArrowBar;");         break; /* ⤓ */
case 10518:  AE("&Rarrtl;");               break; /* ⤖ */
case 10521:  AE("&latail;");               break; /* ⤙ */
case 10522:  AE("&ratail;");               break; /* ⤚ */
case 10523:  AE("&lAtail;");               break; /* ⤛ */
case 10524:  AE("&rAtail;");               break; /* ⤜ */
case 10525:  AE("&larrfs;");               break; /* ⤝ */
case 10526:  AE("&rarrfs;");               break; /* ⤞ */
case 10527:  AE("&larrbfs;");              break; /* ⤟ */
case 10528:  AE("&rarrbfs;");              break; /* ⤠ */
case 10531:  AE("&nwarhk;");               break; /* ⤣ */
case 10532:  AE("&nearhk;");               break; /* ⤤ */
/* searhk aka hksearow */
case 10533:  AE("&searhk;");               break; /* ⤥ */
/* swarhk aka hkswarow */
case 10534:  AE("&swarhk;");               break; /* ⤦ */
case 10535:  AE("&nwnear;");               break; /* ⤧ */
/* toea aka nesear */
case 10536:  AE("&toea;");                 break; /* ⤨ */
/* tosa aka seswar */
case 10537:  AE("&tosa;");                 break; /* ⤩ */
case 10538:  AE("&swnwar;");               break; /* ⤪ */
case 10547:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&nrarrc;"); MCP;                      /* ⤳̸ */
    } else {
        AE("&rarrc;");                            /* ⤳ */
    };                                     break;
case 10549:  AE("&cudarrr;");              break; /* ⤵ */
case 10550:  AE("&ldca;");                 break; /* ⤶ */
case 10551:  AE("&rdca;");                 break; /* ⤷ */
case 10552:  AE("&cudarrl;");              break; /* ⤸ */
case 10553:  AE("&larrpl;");               break; /* ⤹ */
case 10556:  AE("&curarrm;");              break; /* ⤼ */
case 10557:  AE("&cularrp;");              break; /* ⤽ */
case 10565:  AE("&rarrpl;");               break; /* ⥅ */
case 10568:  AE("&harrcir;");              break; /* ⥈ */
case 10569:  AE("&Uarrocir;");             break; /* ⥉ */
case 10570:  AE("&lurdshar;");             break; /* ⥊ */
case 10571:  AE("&ldrushar;");             break; /* ⥋ */
case 10574:  AE("&LeftRightVector;");      break; /* ⥎ */
case 10575:  AE("&RightUpDownVector;");    break; /* ⥏ */
case 10576:  AE("&DownLeftRightVector;");  break; /* ⥐ */
case 10577:  AE("&LeftUpDownVector;");     break; /* ⥑ */
case 10578:  AE("&LeftVectorBar;");        break; /* ⥒ */
case 10579:  AE("&RightVectorBar;");       break; /* ⥓ */
case 10580:  AE("&RightUpVectorBar;");     break; /* ⥔ */
case 10581:  AE("&RightDownVectorBar;");   break; /* ⥕ */
case 10582:  AE("&DownLeftVectorBar;");    break; /* ⥖ */
case 10583:  AE("&DownRightVectorBar;");   break; /* ⥗ */
case 10584:  AE("&LeftUpVectorBar;");      break; /* ⥘ */
case 10585:  AE("&LeftDownVectorBar;");    break; /* ⥙ */
case 10586:  AE("&LeftTeeVector;");        break; /* ⥚ */
case 10587:  AE("&RightTeeVector;");       break; /* ⥛ */
case 10588:  AE("&RightUpTeeVector;");     break; /* ⥜ */
case 10589:  AE("&RightDownTeeVector;");   break; /* ⥝ */
case 10590:  AE("&DownLeftTeeVector;");    break; /* ⥞ */
case 10591:  AE("&DownRightTeeVector;");   break; /* ⥟ */
case 10592:  AE("&LeftUpTeeVector;");      break; /* ⥠ */
case 10593:  AE("&LeftDownTeeVector;");    break; /* ⥡ */
case 10594:  AE("&lHar;");                 break; /* ⥢ */
case 10595:  AE("&uHar;");                 break; /* ⥣ */
case 10596:  AE("&rHar;");                 break; /* ⥤ */
case 10597:  AE("&dHar;");                 break; /* ⥥ */
case 10598:  AE("&luruhar;");              break; /* ⥦ */
case 10599:  AE("&ldrdhar;");              break; /* ⥧ */
case 10600:  AE("&ruluhar;");              break; /* ⥨ */
case 10601:  AE("&rdldhar;");              break; /* ⥩ */
case 10602:  AE("&lharul;");               break; /* ⥪ */
case 10603:  AE("&llhard;");               break; /* ⥫ */
case 10604:  AE("&rharul;");               break; /* ⥬ */
case 10605:  AE("&lrhard;");               break; /* ⥭ */
/* udhar aka UpEquilibrium */
case 10606:  AE("&udhar;");                break; /* ⥮ */
/* duhar aka ReverseUpEquilibrium */
case 10607:  AE("&duhar;");                break; /* ⥯ */
case 10608:  AE("&RoundImplies;");         break; /* ⥰ */
case 10609:  AE("&erarr;");                break; /* ⥱ */
case 10610:  AE("&simrarr;");              break; /* ⥲ */
case 10611:  AE("&larrsim;");              break; /* ⥳ */
case 10612:  AE("&rarrsim;");              break; /* ⥴ */
case 10613:  AE("&rarrap;");               break; /* ⥵ */
case 10614:  AE("&ltlarr;");               break; /* ⥶ */
case 10616:  AE("&gtrarr;");               break; /* ⥸ */
case 10617:  AE("&subrarr;");              break; /* ⥹ */
case 10619:  AE("&suplarr;");              break; /* ⥻ */
case 10620:  AE("&lfisht;");               break; /* ⥼ */
case 10621:  AE("&rfisht;");               break; /* ⥽ */
case 10622:  AE("&ufisht;");               break; /* ⥾ */
case 10623:  AE("&dfisht;");               break; /* ⥿ */
case 10629:  AE("&lopar;");                break; /* ⦅ */
case 10630:  AE("&ropar;");                break; /* ⦆ */
case 10635:  AE("&lbrke;");                break; /* ⦋ */
case 10636:  AE("&rbrke;");                break; /* ⦌ */
case 10637:  AE("&lbrkslu;");              break; /* ⦍ */
case 10638:  AE("&rbrksld;");              break; /* ⦎ */
case 10639:  AE("&lbrksld;");              break; /* ⦏ */
case 10640:  AE("&rbrkslu;");              break; /* ⦐ */
case 10641:  AE("&langd;");                break; /* ⦑ */
case 10642:  AE("&rangd;");                break; /* ⦒ */
case 10643:  AE("&lparlt;");               break; /* ⦓ */
case 10644:  AE("&rpargt;");               break; /* ⦔ */
case 10645:  AE("&gtlPar;");               break; /* ⦕ */
case 10646:  AE("&ltrPar;");               break; /* ⦖ */
case 10650:  AE("&vzigzag;");              break; /* ⦚ */
case 10652:  AE("&vangrt;");               break; /* ⦜ */
case 10653:  AE("&angrtvbd;");             break; /* ⦝ */
case 10660:  AE("&ange;");                 break; /* ⦤ */
case 10661:  AE("&range;");                break; /* ⦥ */
case 10662:  AE("&dwangle;");              break; /* ⦦ */
case 10663:  AE("&uwangle;");              break; /* ⦧ */
case 10664:  AE("&angmsdaa;");             break; /* ⦨ */
case 10665:  AE("&angmsdab;");             break; /* ⦩ */
case 10666:  AE("&angmsdac;");             break; /* ⦪ */
case 10667:  AE("&angmsdad;");             break; /* ⦫ */
case 10668:  AE("&angmsdae;");             break; /* ⦬ */
case 10669:  AE("&angmsdaf;");             break; /* ⦭ */
case 10670:  AE("&angmsdag;");             break; /* ⦮ */
case 10671:  AE("&angmsdah;");             break; /* ⦯ */
case 10672:  AE("&bemptyv;");              break; /* ⦰ */
case 10673:  AE("&demptyv;");              break; /* ⦱ */
case 10674:  AE("&cemptyv;");              break; /* ⦲ */
case 10675:  AE("&raemptyv;");             break; /* ⦳ */
case 10676:  AE("&laemptyv;");             break; /* ⦴ */
case 10677:  AE("&ohbar;");                break; /* ⦵ */
case 10678:  AE("&omid;");                 break; /* ⦶ */
case 10679:  AE("&opar;");                 break; /* ⦷ */
case 10681:  AE("&operp;");                break; /* ⦹ */
case 10683:  AE("&olcross;");              break; /* ⦻ */
case 10684:  AE("&odsold;");               break; /* ⦼ */
case 10686:  AE("&olcir;");                break; /* ⦾ */
case 10687:  AE("&ofcir;");                break; /* ⦿ */
case 10688:  AE("&olt;");                  break; /* ⧀ */
case 10689:  AE("&ogt;");                  break; /* ⧁ */
case 10690:  AE("&cirscir;");              break; /* ⧂ */
case 10691:  AE("&cirE;");                 break; /* ⧃ */
case 10692:  AE("&solb;");                 break; /* ⧄ */
case 10693:  AE("&bsolb;");                break; /* ⧅ */
case 10697:  AE("&boxbox;");               break; /* ⧉ */
case 10701:  AE("&trisb;");                break; /* ⧍ */
case 10702:  AE("&rtriltri;");             break; /* ⧎ */
case 10703:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotLeftTriangleBar;"); MCP;          /* ⧏̸ */
    } else {
        AE("&LeftTriangleBar;");                  /* ⧏ */
    };                                     break;
case 10704:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotRightTriangleBar;"); MCP;         /* ⧐̸ */
    } else {
        AE("&RightTriangleBar;");                 /* ⧐ */
    };                                     break;
case 10716:  AE("&iinfin;");               break; /* ⧜ */
case 10717:  AE("&infintie;");             break; /* ⧝ */
case 10718:  AE("&nvinfin;");              break; /* ⧞ */
case 10723:  AE("&eparsl;");               break; /* ⧣ */
case 10724:  AE("&smeparsl;");             break; /* ⧤ */
case 10725:  AE("&eqvparsl;");             break; /* ⧥ */
/* lozf aka blacklozenge */
case 10731:  AE("&lozf;");                 break; /* ⧫ */
case 10740:  AE("&RuleDelayed;");          break; /* ⧴ */
case 10742:  AE("&dsol;");                 break; /* ⧶ */
/* xodot aka bigodot */
case 10752:  AE("&xodot;");                break; /* ⨀ */
/* xoplus aka bigoplus */
case 10753:  AE("&xoplus;");               break; /* ⨁ */
/* xotime aka bigotimes */
case 10754:  AE("&xotime;");               break; /* ⨂ */
/* xuplus aka biguplus */
case 10756:  AE("&xuplus;");               break; /* ⨄ */
/* xsqcup aka bigsqcup */
case 10758:  AE("&xsqcup;");               break; /* ⨆ */
/* qint aka iiiint */
case 10764:  AE("&qint;");                 break; /* ⨌ */
case 10765:  AE("&fpartint;");             break; /* ⨍ */
case 10768:  AE("&cirfnint;");             break; /* ⨐ */
case 10769:  AE("&awint;");                break; /* ⨑ */
case 10770:  AE("&rppolint;");             break; /* ⨒ */
case 10771:  AE("&scpolint;");             break; /* ⨓ */
case 10772:  AE("&npolint;");              break; /* ⨔ */
case 10773:  AE("&pointint;");             break; /* ⨕ */
case 10774:  AE("&quatint;");              break; /* ⨖ */
case 10775:  AE("&intlarhk;");             break; /* ⨗ */
case 10786:  AE("&pluscir;");              break; /* ⨢ */
case 10787:  AE("&plusacir;");             break; /* ⨣ */
case 10788:  AE("&simplus;");              break; /* ⨤ */
case 10789:  AE("&plusdu;");               break; /* ⨥ */
case 10790:  AE("&plussim;");              break; /* ⨦ */
case 10791:  AE("&plustwo;");              break; /* ⨧ */
case 10793:  AE("&mcomma;");               break; /* ⨩ */
case 10794:  AE("&minusdu;");              break; /* ⨪ */
case 10797:  AE("&loplus;");               break; /* ⨭ */
case 10798:  AE("&roplus;");               break; /* ⨮ */
case 10799:  AE("&Cross;");                break; /* ⨯ */
case 10800:  AE("&timesd;");               break; /* ⨰ */
case 10801:  AE("&timesbar;");             break; /* ⨱ */
case 10803:  AE("&smashp;");               break; /* ⨳ */
case 10804:  AE("&lotimes;");              break; /* ⨴ */
case 10805:  AE("&rotimes;");              break; /* ⨵ */
case 10806:  AE("&otimesas;");             break; /* ⨶ */
case 10807:  AE("&Otimes;");               break; /* ⨷ */
case 10808:  AE("&odiv;");                 break; /* ⨸ */
case 10809:  AE("&triplus;");              break; /* ⨹ */
case 10810:  AE("&triminus;");             break; /* ⨺ */
case 10811:  AE("&tritime;");              break; /* ⨻ */
/* iprod aka intprod */
case 10812:  AE("&iprod;");                break; /* ⨼ */
case 10815:  AE("&amalg;");                break; /* ⨿ */
case 10816:  AE("&capdot;");               break; /* ⩀ */
case 10818:  AE("&ncup;");                 break; /* ⩂ */
case 10819:  AE("&ncap;");                 break; /* ⩃ */
case 10820:  AE("&capand;");               break; /* ⩄ */
case 10821:  AE("&cupor;");                break; /* ⩅ */
case 10822:  AE("&cupcap;");               break; /* ⩆ */
case 10823:  AE("&capcup;");               break; /* ⩇ */
case 10824:  AE("&cupbrcap;");             break; /* ⩈ */
case 10825:  AE("&capbrcup;");             break; /* ⩉ */
case 10826:  AE("&cupcup;");               break; /* ⩊ */
case 10827:  AE("&capcap;");               break; /* ⩋ */
case 10828:  AE("&ccups;");                break; /* ⩌ */
case 10829:  AE("&ccaps;");                break; /* ⩍ */
case 10832:  AE("&ccupssm;");              break; /* ⩐ */
case 10835:  AE("&And;");                  break; /* ⩓ */
case 10836:  AE("&Or;");                   break; /* ⩔ */
case 10837:  AE("&andand;");               break; /* ⩕ */
case 10838:  AE("&oror;");                 break; /* ⩖ */
case 10839:  AE("&orslope;");              break; /* ⩗ */
case 10840:  AE("&andslope;");             break; /* ⩘ */
case 10842:  AE("&andv;");                 break; /* ⩚ */
case 10843:  AE("&orv;");                  break; /* ⩛ */
case 10844:  AE("&andd;");                 break; /* ⩜ */
case 10845:  AE("&ord;");                  break; /* ⩝ */
case 10847:  AE("&wedbar;");               break; /* ⩟ */
case 10854:  AE("&sdote;");                break; /* ⩦ */
case 10858:  AE("&simdot;");               break; /* ⩪ */
case 10861:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&ncongdot;"); MCP;                    /* ⩭̸ */
    } else {
        AE("&congdot;");                          /* ⩭ */
    };                                     break;
case 10862:  AE("&easter;");               break; /* ⩮ */
case 10863:  AE("&apacir;");               break; /* ⩯ */
case 10864:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&napE;"); MCP;                        /* ⩰̸ */
    } else {
        AE("&apE;");                              /* ⩰ */
    };                                     break;
case 10865:  AE("&eplus;");                break; /* ⩱ */
case 10866:  AE("&pluse;");                break; /* ⩲ */
case 10867:  AE("&Esim;");                 break; /* ⩳ */
case 10868:  AE("&Colone;");               break; /* ⩴ */
case 10869:  AE("&Equal;");                break; /* ⩵ */
/* eDDot aka ddotseq */
case 10871:  AE("&eDDot;");                break; /* ⩷ */
case 10872:  AE("&equivDD;");              break; /* ⩸ */
case 10873:  AE("&ltcir;");                break; /* ⩹ */
case 10874:  AE("&gtcir;");                break; /* ⩺ */
case 10875:  AE("&ltquest;");              break; /* ⩻ */
case 10876:  AE("&gtquest;");              break; /* ⩼ */
case 10877:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* les aka NotLessSlantEqual or nleqslant */
        AE("&nles;"); MCP;                        /* ⩽̸ */
    } else {
        /* les aka LessSlantEqual or leqslant */
        AE("&les;");                              /* ⩽ */
    };                                     break;
case 10878:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* ges aka NotGreaterSlantEqual or ngeqslant */
        AE("&nges;"); MCP;                        /* ⩾̸ */
    } else {
        /* ges aka GreaterSlantEqual or geqslant */
        AE("&ges;");                              /* ⩾ */
    };                                     break;
case 10879:  AE("&lesdot;");               break; /* ⩿ */
case 10880:  AE("&gesdot;");               break; /* ⪀ */
case 10881:  AE("&lesdoto;");              break; /* ⪁ */
case 10882:  AE("&gesdoto;");              break; /* ⪂ */
case 10883:  AE("&lesdotor;");             break; /* ⪃ */
case 10884:  AE("&gesdotol;");             break; /* ⪄ */
/* lap aka lessapprox */
case 10885:  AE("&lap;");                  break; /* ⪅ */
/* gap aka gtrapprox */
case 10886:  AE("&gap;");                  break; /* ⪆ */
/* lne aka lneq */
case 10887:  AE("&lne;");                  break; /* ⪇ */
/* gne aka gneq */
case 10888:  AE("&gne;");                  break; /* ⪈ */
/* lnap aka lnapprox */
case 10889:  AE("&lnap;");                 break; /* ⪉ */
/* gnap aka gnapprox */
case 10890:  AE("&gnap;");                 break; /* ⪊ */
/* lEg aka lesseqqgtr */
case 10891:  AE("&lEg;");                  break; /* ⪋ */
/* gEl aka gtreqqless */
case 10892:  AE("&gEl;");                  break; /* ⪌ */
case 10893:  AE("&lsime;");                break; /* ⪍ */
case 10894:  AE("&gsime;");                break; /* ⪎ */
case 10895:  AE("&lsimg;");                break; /* ⪏ */
case 10896:  AE("&gsiml;");                break; /* ⪐ */
case 10897:  AE("&lgE;");                  break; /* ⪑ */
case 10898:  AE("&glE;");                  break; /* ⪒ */
case 10899:  AE("&lesges;");               break; /* ⪓ */
case 10900:  AE("&gesles;");               break; /* ⪔ */
/* els aka eqslantless */
case 10901:  AE("&els;");                  break; /* ⪕ */
/* egs aka eqslantgtr */
case 10902:  AE("&egs;");                  break; /* ⪖ */
case 10903:  AE("&elsdot;");               break; /* ⪗ */
case 10904:  AE("&egsdot;");               break; /* ⪘ */
case 10905:  AE("&el;");                   break; /* ⪙ */
case 10906:  AE("&eg;");                   break; /* ⪚ */
case 10909:  AE("&siml;");                 break; /* ⪝ */
case 10910:  AE("&simg;");                 break; /* ⪞ */
case 10911:  AE("&simlE;");                break; /* ⪟ */
case 10912:  AE("&simgE;");                break; /* ⪠ */
case 10913:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotNestedLessLess;"); MCP;           /* ⪡̸ */
    } else {
        AE("&LessLess;");                         /* ⪡ */
    };                                     break;
case 10914:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        AE("&NotNestedGreaterGreater;"); MCP;     /* ⪢̸ */
    } else {
        AE("&GreaterGreater;");                   /* ⪢ */
    };                                     break;
case 10916:  AE("&glj;");                  break; /* ⪤ */
case 10917:  AE("&gla;");                  break; /* ⪥ */
case 10918:  AE("&ltcc;");                 break; /* ⪦ */
case 10919:  AE("&gtcc;");                 break; /* ⪧ */
case 10920:  AE("&lescc;");                break; /* ⪨ */
case 10921:  AE("&gescc;");                break; /* ⪩ */
case 10922:  AE("&smt;");                  break; /* ⪪ */
case 10923:  AE("&lat;");                  break; /* ⪫ */
case 10924:  TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&smtes;"); MCP;                       /* ⪬︀ */
    } else {
        AE("&smte;");                             /* ⪬ */
    };                                     break;
case 10925:  TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        AE("&lates;"); MCP;                       /* ⪭︀ */
    } else {
        AE("&late;");                             /* ⪭ */
    };                                     break;
case 10926:  AE("&bumpE;");                break; /* ⪮ */
case 10927:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* pre aka NotPrecedesEqual or npreceq */
        AE("&npre;"); MCP;                        /* ⪯̸ */
    } else {
        /* pre aka PrecedesEqual or preceq */
        AE("&pre;");                              /* ⪯ */
    };                                     break;
case 10928:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* sce aka NotSucceedsEqual or nsucceq */
        AE("&nsce;"); MCP;                        /* ⪰̸ */
    } else {
        /* sce aka SucceedsEqual or succeq */
        AE("&sce;");                              /* ⪰ */
    };                                     break;
case 10931:  AE("&prE;");                  break; /* ⪳ */
case 10932:  AE("&scE;");                  break; /* ⪴ */
/* prnE aka precneqq */
case 10933:  AE("&prnE;");                 break; /* ⪵ */
/* scnE aka succneqq */
case 10934:  AE("&scnE;");                 break; /* ⪶ */
/* prap aka precapprox */
case 10935:  AE("&prap;");                 break; /* ⪷ */
/* scap aka succapprox */
case 10936:  AE("&scap;");                 break; /* ⪸ */
/* prnap aka precnapprox */
case 10937:  AE("&prnap;");                break; /* ⪹ */
/* scnap aka succnapprox */
case 10938:  AE("&scnap;");                break; /* ⪺ */
case 10939:  AE("&Pr;");                   break; /* ⪻ */
case 10940:  AE("&Sc;");                   break; /* ⪼ */
case 10941:  AE("&subdot;");               break; /* ⪽ */
case 10942:  AE("&supdot;");               break; /* ⪾ */
case 10943:  AE("&subplus;");              break; /* ⪿ */
case 10944:  AE("&supplus;");              break; /* ⫀ */
case 10945:  AE("&submult;");              break; /* ⫁ */
case 10946:  AE("&supmult;");              break; /* ⫂ */
case 10947:  AE("&subedot;");              break; /* ⫃ */
case 10948:  AE("&supedot;");              break; /* ⫄ */
case 10949:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* subE aka nsubseteqq */
        AE("&nsubE;"); MCP;                       /* ⫅̸ */
    } else {
        /* subE aka subseteqq */
        AE("&subE;");                             /* ⫅ */
    };                                     break;
case 10950:  TWOCPE;
    if (clen2 && uniChar2 == 824) { 
        /* supE aka nsupseteqq */
        AE("&nsupE;"); MCP;                       /* ⫆̸ */
    } else {
        /* supE aka supseteqq */
        AE("&supE;");                             /* ⫆ */
    };                                     break;
case 10951:  AE("&subsim;");               break; /* ⫇ */
case 10952:  AE("&supsim;");               break; /* ⫈ */
case 10955:  TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        /* subnE aka varsubsetneqq */
        AE("&vsubnE;"); MCP;                      /* ⫋︀ */
    } else {
        /* subnE aka subsetneqq */
        AE("&subnE;");                            /* ⫋ */
    };                                     break;
case 10956:  TWOCPE;
    if (clen2 && uniChar2 == 65024) { 
        /* supnE aka varsupsetneqq */
        AE("&vsupnE;"); MCP;                      /* ⫌︀ */
    } else {
        /* supnE aka supsetneqq */
        AE("&supnE;");                            /* ⫌ */
    };                                     break;
case 10959:  AE("&csub;");                 break; /* ⫏ */
case 10960:  AE("&csup;");                 break; /* ⫐ */
case 10961:  AE("&csube;");                break; /* ⫑ */
case 10962:  AE("&csupe;");                break; /* ⫒ */
case 10963:  AE("&subsup;");               break; /* ⫓ */
case 10964:  AE("&supsub;");               break; /* ⫔ */
case 10965:  AE("&subsub;");               break; /* ⫕ */
case 10966:  AE("&supsup;");               break; /* ⫖ */
case 10967:  AE("&suphsub;");              break; /* ⫗ */
case 10968:  AE("&supdsub;");              break; /* ⫘ */
case 10969:  AE("&forkv;");                break; /* ⫙ */
case 10970:  AE("&topfork;");              break; /* ⫚ */
case 10971:  AE("&mlcp;");                 break; /* ⫛ */
/* Dashv aka DoubleLeftTee */
case 10980:  AE("&Dashv;");                break; /* ⫤ */
case 10982:  AE("&Vdashl;");               break; /* ⫦ */
case 10983:  AE("&Barv;");                 break; /* ⫧ */
case 10984:  AE("&vBar;");                 break; /* ⫨ */
case 10985:  AE("&vBarv;");                break; /* ⫩ */
case 10987:  AE("&Vbar;");                 break; /* ⫫ */
case 10988:  AE("&Not;");                  break; /* ⫬ */
case 10989:  AE("&bNot;");                 break; /* ⫭ */
case 10990:  AE("&rnmid;");                break; /* ⫮ */
case 10991:  AE("&cirmid;");               break; /* ⫯ */
case 10992:  AE("&midcir;");               break; /* ⫰ */
case 10993:  AE("&topcir;");               break; /* ⫱ */
case 10994:  AE("&nhpar;");                break; /* ⫲ */
case 10995:  AE("&parsim;");               break; /* ⫳ */
case 11005:  TWOCPE;
    if (clen2 && uniChar2 == 8421) { 
        AE("&nparsl;"); MCP;                      /* ⫽⃥ */
    } else {
        AE("&parsl;");                            /* ⫽ */
    };                                     break;
case 64256:  AE("&fflig;");                break; /* ﬀ */
case 64257:  AE("&filig;");                break; /* ﬁ */
case 64258:  AE("&fllig;");                break; /* ﬂ */
case 64259:  AE("&ffilig;");               break; /* ﬃ */
case 64260:  AE("&ffllig;");               break; /* ﬄ */
case 119964: AE("&Ascr;");                 break; /* 𝒜 */
case 119966: AE("&Cscr;");                 break; /* 𝒞 */
case 119967: AE("&Dscr;");                 break; /* 𝒟 */
case 119970: AE("&Gscr;");                 break; /* 𝒢 */
case 119973: AE("&Jscr;");                 break; /* 𝒥 */
case 119974: AE("&Kscr;");                 break; /* 𝒦 */
case 119977: AE("&Nscr;");                 break; /* 𝒩 */
case 119978: AE("&Oscr;");                 break; /* 𝒪 */
case 119979: AE("&Pscr;");                 break; /* 𝒫 */
case 119980: AE("&Qscr;");                 break; /* 𝒬 */
case 119982: AE("&Sscr;");                 break; /* 𝒮 */
case 119983: AE("&Tscr;");                 break; /* 𝒯 */
case 119984: AE("&Uscr;");                 break; /* 𝒰 */
case 119985: AE("&Vscr;");                 break; /* 𝒱 */
case 119986: AE("&Wscr;");                 break; /* 𝒲 */
case 119987: AE("&Xscr;");                 break; /* 𝒳 */
case 119988: AE("&Yscr;");                 break; /* 𝒴 */
case 119989: AE("&Zscr;");                 break; /* 𝒵 */
case 119990: AE("&ascr;");                 break; /* 𝒶 */
case 119991: AE("&bscr;");                 break; /* 𝒷 */
case 119992: AE("&cscr;");                 break; /* 𝒸 */
case 119993: AE("&dscr;");                 break; /* 𝒹 */
case 119995: AE("&fscr;");                 break; /* 𝒻 */
case 119997: AE("&hscr;");                 break; /* 𝒽 */
case 119998: AE("&iscr;");                 break; /* 𝒾 */
case 119999: AE("&jscr;");                 break; /* 𝒿 */
case 120000: AE("&kscr;");                 break; /* 𝓀 */
case 120001: AE("&lscr;");                 break; /* 𝓁 */
case 120002: AE("&mscr;");                 break; /* 𝓂 */
case 120003: AE("&nscr;");                 break; /* 𝓃 */
case 120005: AE("&pscr;");                 break; /* 𝓅 */
case 120006: AE("&qscr;");                 break; /* 𝓆 */
case 120007: AE("&rscr;");                 break; /* 𝓇 */
case 120008: AE("&sscr;");                 break; /* 𝓈 */
case 120009: AE("&tscr;");                 break; /* 𝓉 */
case 120010: AE("&uscr;");                 break; /* 𝓊 */
case 120011: AE("&vscr;");                 break; /* 𝓋 */
case 120012: AE("&wscr;");                 break; /* 𝓌 */
case 120013: AE("&xscr;");                 break; /* 𝓍 */
case 120014: AE("&yscr;");                 break; /* 𝓎 */
case 120015: AE("&zscr;");                 break; /* 𝓏 */
case 120068: AE("&Afr;");                  break; /* 𝔄 */
case 120069: AE("&Bfr;");                  break; /* 𝔅 */
case 120071: AE("&Dfr;");                  break; /* 𝔇 */
case 120072: AE("&Efr;");                  break; /* 𝔈 */
case 120073: AE("&Ffr;");                  break; /* 𝔉 */
case 120074: AE("&Gfr;");                  break; /* 𝔊 */
case 120077: AE("&Jfr;");                  break; /* 𝔍 */
case 120078: AE("&Kfr;");                  break; /* 𝔎 */
case 120079: AE("&Lfr;");                  break; /* 𝔏 */
case 120080: AE("&Mfr;");                  break; /* 𝔐 */
case 120081: AE("&Nfr;");                  break; /* 𝔑 */
case 120082: AE("&Ofr;");                  break; /* 𝔒 */
case 120083: AE("&Pfr;");                  break; /* 𝔓 */
case 120084: AE("&Qfr;");                  break; /* 𝔔 */
case 120086: AE("&Sfr;");                  break; /* 𝔖 */
case 120087: AE("&Tfr;");                  break; /* 𝔗 */
case 120088: AE("&Ufr;");                  break; /* 𝔘 */
case 120089: AE("&Vfr;");                  break; /* 𝔙 */
case 120090: AE("&Wfr;");                  break; /* 𝔚 */
case 120091: AE("&Xfr;");                  break; /* 𝔛 */
case 120092: AE("&Yfr;");                  break; /* 𝔜 */
case 120094: AE("&afr;");                  break; /* 𝔞 */
case 120095: AE("&bfr;");                  break; /* 𝔟 */
case 120096: AE("&cfr;");                  break; /* 𝔠 */
case 120097: AE("&dfr;");                  break; /* 𝔡 */
case 120098: AE("&efr;");                  break; /* 𝔢 */
case 120099: AE("&ffr;");                  break; /* 𝔣 */
case 120100: AE("&gfr;");                  break; /* 𝔤 */
case 120101: AE("&hfr;");                  break; /* 𝔥 */
case 120102: AE("&ifr;");                  break; /* 𝔦 */
case 120103: AE("&jfr;");                  break; /* 𝔧 */
case 120104: AE("&kfr;");                  break; /* 𝔨 */
case 120105: AE("&lfr;");                  break; /* 𝔩 */
case 120106: AE("&mfr;");                  break; /* 𝔪 */
case 120107: AE("&nfr;");                  break; /* 𝔫 */
case 120108: AE("&ofr;");                  break; /* 𝔬 */
case 120109: AE("&pfr;");                  break; /* 𝔭 */
case 120110: AE("&qfr;");                  break; /* 𝔮 */
case 120111: AE("&rfr;");                  break; /* 𝔯 */
case 120112: AE("&sfr;");                  break; /* 𝔰 */
case 120113: AE("&tfr;");                  break; /* 𝔱 */
case 120114: AE("&ufr;");                  break; /* 𝔲 */
case 120115: AE("&vfr;");                  break; /* 𝔳 */
case 120116: AE("&wfr;");                  break; /* 𝔴 */
case 120117: AE("&xfr;");                  break; /* 𝔵 */
case 120118: AE("&yfr;");                  break; /* 𝔶 */
case 120119: AE("&zfr;");                  break; /* 𝔷 */
case 120120: AE("&Aopf;");                 break; /* 𝔸 */
case 120121: AE("&Bopf;");                 break; /* 𝔹 */
case 120123: AE("&Dopf;");                 break; /* 𝔻 */
case 120124: AE("&Eopf;");                 break; /* 𝔼 */
case 120125: AE("&Fopf;");                 break; /* 𝔽 */
case 120126: AE("&Gopf;");                 break; /* 𝔾 */
case 120128: AE("&Iopf;");                 break; /* 𝕀 */
case 120129: AE("&Jopf;");                 break; /* 𝕁 */
case 120130: AE("&Kopf;");                 break; /* 𝕂 */
case 120131: AE("&Lopf;");                 break; /* 𝕃 */
case 120132: AE("&Mopf;");                 break; /* 𝕄 */
case 120134: AE("&Oopf;");                 break; /* 𝕆 */
case 120138: AE("&Sopf;");                 break; /* 𝕊 */
case 120139: AE("&Topf;");                 break; /* 𝕋 */
case 120140: AE("&Uopf;");                 break; /* 𝕌 */
case 120141: AE("&Vopf;");                 break; /* 𝕍 */
case 120142: AE("&Wopf;");                 break; /* 𝕎 */
case 120143: AE("&Xopf;");                 break; /* 𝕏 */
case 120144: AE("&Yopf;");                 break; /* 𝕐 */
case 120146: AE("&aopf;");                 break; /* 𝕒 */
case 120147: AE("&bopf;");                 break; /* 𝕓 */
case 120148: AE("&copf;");                 break; /* 𝕔 */
case 120149: AE("&dopf;");                 break; /* 𝕕 */
case 120150: AE("&eopf;");                 break; /* 𝕖 */
case 120151: AE("&fopf;");                 break; /* 𝕗 */
case 120152: AE("&gopf;");                 break; /* 𝕘 */
case 120153: AE("&hopf;");                 break; /* 𝕙 */
case 120154: AE("&iopf;");                 break; /* 𝕚 */
case 120155: AE("&jopf;");                 break; /* 𝕛 */
case 120156: AE("&kopf;");                 break; /* 𝕜 */
case 120157: AE("&lopf;");                 break; /* 𝕝 */
case 120158: AE("&mopf;");                 break; /* 𝕞 */
case 120159: AE("&nopf;");                 break; /* 𝕟 */
case 120160: AE("&oopf;");                 break; /* 𝕠 */
case 120161: AE("&popf;");                 break; /* 𝕡 */
case 120162: AE("&qopf;");                 break; /* 𝕢 */
case 120163: AE("&ropf;");                 break; /* 𝕣 */
case 120164: AE("&sopf;");                 break; /* 𝕤 */
case 120165: AE("&topf;");                 break; /* 𝕥 */
case 120166: AE("&uopf;");                 break; /* 𝕦 */
case 120167: AE("&vopf;");                 break; /* 𝕧 */
case 120168: AE("&wopf;");                 break; /* 𝕨 */
case 120169: AE("&xopf;");                 break; /* 𝕩 */
case 120170: AE("&yopf;");                 break; /* 𝕪 */
case 120171: AE("&zopf;");                 break; /* 𝕫 */
