
#ifndef JSON_MAX_NESTING
# define JSON_MAX_NESTING 2000
#endif

#ifndef JSON_OBJECT_CONTAINER
# define JSON_OBJECT_CONTAINER "objectcontainer"
#endif

#ifndef JSON_ARRAY_CONTAINER
# define JSON_ARRAY_CONTAINER "arraycontainer"
#endif

typedef enum {
    JSON_START,
    JSON_WITHIN_ARRAY,
    JSON_WITHIN_OBJECT
} JSONWithin;

#define JSON_ARRAY 1
#define JSON_OBJECT 2
#define JSON_NULL 3
#define JSON_TRUE 4
#define JSON_FALSE 5
#define JSON_STRING 6
#define JSON_NUMBER 7


domDocument *
JSON_Parse (
    char *json,    /* Complete text of the json string being parsed */
    char *documentElement, /* name of the root element, may be NULL */
    int   maxnesting,
    char **errStr,
    domLength *byteIndex
    );

