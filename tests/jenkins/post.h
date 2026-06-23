/**
  Copyright (c) 2012-2019 by Autodesk, Inc.
  http://www.autodesk.com
  Not for redistribution
*/

#pragma once

/*
  Attention:

  This interface is subject to change without notification.

  Recompilation and reimplementation may be required between different versions of the OEM module.
*/

#if (!defined(API))
#if defined(_WIN32)
#  define API __declspec(dllimport)
#elif defined(__APPLE__)
#elif defined(__GNUC__)
#  define API __attribute__ ((dllimport))
#endif
#endif

#undef PREFIX
#define PREFIX(identifier) cipost_##identifier

#define _COM_AUTODESK__POST_DEPRECATED_API

#if defined(_WIN32)
#pragma pack(push, 8)
#endif

// C interface

extern "C" {

/**
  Status codes.
*/
enum {
  POST_STATUS__OK = 0,
  POST_STATUS__FAILED = 1,
  POST_STATUS__INVALID_ARGUMENT = 2,
  POST_STATUS__ABORTED = 3,
  POST_STATUS__FILE_DOESNT_EXIST = 4,
  POST_STATUS__INVALID_MACHINE_CONFIGURATION = 5
};

#if defined(_COM_AUTODESK__POST_DEPRECATED_API)
/**
  Status codes.
*/
enum {
  CIPOST_STATUS__OK = 0,
  CIPOST_STATUS__FAILED = 1,
  CIPOST_STATUS__INVALID_ARGUMENT = 2,
  CIPOST_STATUS__ABORTED = 3,
  CIPOST_STATUS__FILE_DOESNT_EXIST = 4,
  CIPOST_STATUS__INVALID_MACHINE_CONFIGURATION = 5
};
#endif

/** A 2D range. */
struct PREFIX(Range) {
  double minimum;
  double maximum;
};

/** A 3D vector. */
struct PREFIX(Vector) {
  double x;
  double y;
  double z;
};

enum PREFIX(Preference) {
  PREFIX(PREFER_NOTHING),
  PREFIX(PREFER_POSITIVE),
  PREFIX(PREFER_NEGATIVE)
};

/** Machine axis specification. */
struct PREFIX(Axis) {
  int coordinate; ///< The coordinate id: 0:X, 1:Y, 2:Z, -1 if not used - all other values are not allowed
  bool table; // head if false
  PREFIX(Vector) offset;
  PREFIX(Vector) axis;
  PREFIX(Range) workRange;
  PREFIX(Preference) preference;
};

/**
  Returns a pointer to "http://www.hsmworks.com/namespace/post".
  You have to copy the string if you want to use the string in a later context.
  Do not attemt to release the result. The URI is intended for verification of
  the loaded module.
*/
API unsigned int PREFIX(getUri)(char** uri);

/**
  Returns the version of the module.

  @param major The major version number.
  @param minor The minor version number.
  @param micro The micro version number.
*/
API unsigned int PREFIX(getVersion)(unsigned int* major, unsigned int* minor, unsigned int* micro);

/**
  Returns the API compatibility identifier. The identifier is updated when the
  API breaks backwards compatibility.

  @param compatibility The API compatibility identifier.
*/
API unsigned int PREFIX(getCompatibility)(unsigned int* compatibility);

enum {

  MAXIMUM_INTERACTION_TEXT_LENGTH = 1024
};

/**
  Interaction callback.
 
  @param context The user-defined context value.
  @param title The title (could be empty string).
  @param description The description.
  @param text The returned text. The maximum length including the null-terminator is MAXIMUM_INTERACTION_TEXT_LENGTH.

  Return POST_STATUS__OK.
*/
typedef unsigned int PREFIX(InteractionCallback)(void* context, const wchar_t* title, const wchar_t* description, wchar_t* text);

/** Message type used with MessageCallback. */
enum {

  POST__UNSPECIFIED = 0, /**< Unspecified message type. */
  POST__ERROR = 1, /**< Error message type. */
  POST__WARNING = 2, /**< Warning message type. */
  POST__INFORMATION = 3, /**< Information message type. */
  POST__HINT = 4, /**< Hint message type. */
  POST__DEBUG = 5 /**< Debug message type. */
};

#if defined(_COM_AUTODESK__POST_DEPRECATED_API)
/** Message type used with MessageCallback. */
enum {

  CIPOST__UNSPECIFIED = 0, /**< Unspecified message type. */
  CIPOST__ERROR = 1, /**< Error message type. */
  CIPOST__WARNING = 2, /**< Warning message type. */
  CIPOST__INFORMATION = 3, /**< Information message type. */
  CIPOST__HINT = 4, /**< Hint message type. */
  CIPOST__DEBUG = 5 /**< Debug message type. */
};
#endif

/**
  Message callback.
 
  @param context The user-defined context value.
  @param type The type of the message.
  @param text The text.

  Return POST_STATUS__OK.
*/
typedef unsigned int PREFIX(MessageCallback)(void* context, unsigned int type, const wchar_t* text);

/**
  Progress callback.
 
  @param context The user-defined context value.
  @param progress The current progress.

  Return POST_STATUS__OK to continue.
*/
typedef unsigned int PREFIX(ProgressCallback)(void* context, double progress);

/**
  Property callback.

  @param context User-defined context value.
  @param name The name of the property.
  @param type The type of the value.
  @param value Pointer to the value of the specified type.

  Return POST_STATUS__OK to continue.
*/
typedef unsigned int PREFIX(PropertyCallback)(void* context, const wchar_t* name, unsigned int type, void* value);

/** A property set. */
struct PREFIX(PropertySet);

/**
  Enumerates the properties of the specified configuration script.

  @param context Context value provided to callback.
  @param propertySet The property set.
  @param callback The property callback function.
*/
API unsigned int PREFIX(enumPropertySet)(void* context, PREFIX(PropertySet)* propertySet, PREFIX(PropertyCallback) callback);

/**
  Enumerates the properties of the specified configuration script.

  @param context Context value provided to callback.
  @param configPath The configuration path.
  @param key The decryption key.
  @param callback The property callback function.
*/
// TAG: will be deprecated
API unsigned int PREFIX(enumProperties)(void* context, const wchar_t* configPath, const wchar_t* key, PREFIX(PropertyCallback) callback);

/**
  Returns the JSON properties.
  
  @param configPath The configuration path.
  @param json The JSON. The maximum length is POST_MAXIMUM_PROPERTY_JSON_LENGTH. The string is in UTF-8 and will be null terminated.

  \since 41551
*/
API unsigned int PREFIX(getProperties)(void* context, const wchar_t* configPath, const wchar_t* key, char* json);

/**
  Returns the machine configuration from the specified configuration script if found.

  @param configPath The configuration path.
  @param xml The XML. The maximum length is POST_MAXIMUM_XML_TEXT_LENGTH.
*/
API unsigned int PREFIX(getMachineConfig)(const wchar_t* configPath, wchar_t* xml);

/**
  Property callback types.
*/
enum {
  POST_PROPERTY_TYPE__UNSPECIFIED = 0, ///< Unspecified type.
  POST_PROPERTY_TYPE__BOOL = 1, ///< bool type.
  POST_PROPERTY_TYPE__INT = 2, ///< int type.
  POST_PROPERTY_TYPE__DOUBLE = 3, ///< double type.
  POST_PROPERTY_TYPE__TEXT = 4 ///< const wchar_t* type.
};

#if defined(_COM_AUTODESK__POST_DEPRECATED_API)
/**
  Property callback types.
*/
enum {
  CIPOST_PROPERTY_TYPE__UNSPECIFIED = 0, ///< Unspecified type.
  CIPOST_PROPERTY_TYPE__BOOL = 1, ///< bool type.
  CIPOST_PROPERTY_TYPE__INT = 2, ///< int type.
  CIPOST_PROPERTY_TYPE__DOUBLE = 3, ///< double type.
  CIPOST_PROPERTY_TYPE__TEXT = 4 ///< const wchar_t* type.
};
#endif

/** NC stream. */
struct PREFIX(NCStream);

/**
  Property set callback.

  @param context The context.
  @param propertySet The property set. Do not destroy this.
*/
typedef unsigned int PREFIX(PropertySetCallback)(void* context, PREFIX(PropertySet)* propertySet);

/**
  Creates a new property set. Invoke destroyPropertySet() on the returned property set when done.
  
  @param properties The properties.

  @return 0 on error.
*/
API PREFIX(PropertySet)* PREFIX(createPropertySet)();

/**
  Sets the specified property as a boolean.
  
  @param propertySet The property set.
  @param name The name of the property.
  @param value The value.
*/
API unsigned int PREFIX(setPropertyBool)(PREFIX(PropertySet)* propertySet, const wchar_t* name, bool value);

/**
  Sets the specified property as an integer.
  
  @param propertySet The property set.
  @param name The name of the property.
  @param value The value.
*/
API unsigned int PREFIX(setPropertyInt)(PREFIX(PropertySet)* propertySet, const wchar_t* name, int value);

/**
  Sets the specified property as a double.
  
  @param propertySet The property set.
  @param name The name of the property.
  @param value The value.
*/
API unsigned int PREFIX(setPropertyDouble)(PREFIX(PropertySet)* propertySet, const wchar_t* name, double value);

/**
  Sets the specified property as text.
  
  @param propertySet The property set.
  @param name The name of the property.
  @param value The value.
*/
API unsigned int PREFIX(setPropertyText)(PREFIX(PropertySet)* propertySet, const wchar_t* name, const wchar_t* value);

/**
  Destroys the specified properties.

  @param propertySet The properties (may be 0).
*/
API unsigned int PREFIX(destroyPropertySet)(PREFIX(PropertySet)* propertySet);

/**
  Posts the specified intermediate file to the specified output.

  One and only one must stream and intermediatePath must be 0.

  @param context User-defined context used for callbacks.
  @param configPath The path of the post configuration file.
  @param logPath The path of the log file (may be 0).
  @param intermediatePath The path of the intermediate file.
  @param outputPath The path of the output file.
  @param key The decryption key.
  @param stream NC stream (reserved).
  @param machineConfiguration The machine configuration as XML (may be 0).
  @param propertySet The properties (may be 0).
  @param userDefinedPropertySet The user-defined properties (may be 0).
  @param propertySetCallback The property set callback (may be 0).
  @param interactionCallback Interaction callback (may be 0 in which case interaction is disabled).
  @param messageCallback Message callback (may be 0).
  @param progressCallback Progress callback (may be 0).
*/
API unsigned int PREFIX(post)(void* context,
                              const wchar_t* configPath,
                              const wchar_t* logPath,
                              const wchar_t* intermediatePath,
                              const wchar_t* outputPath,
                              const wchar_t* key,
                              PREFIX(NCStream)* stream,
                              const wchar_t* machineConfigurationXML,
                              PREFIX(PropertySet)* propertySet,
                              PREFIX(PropertySet)* userDefinedPropertySet,
                              PREFIX(PropertySetCallback) propertySetCallback,
                              PREFIX(InteractionCallback) interactionCallback,
                              PREFIX(MessageCallback) messageCallback,
                              PREFIX(ProgressCallback) progressCallback);

enum {

  POST_MAXIMUM_LOCALIZATION_TEXT_LENGTH = 1024,
  POST_MAXIMUM_PROPERTY_JSON_LENGTH = 16 * 1024,
  POST_MAXIMUM_XML_TEXT_LENGTH = 16 * 1024
};

#if defined(_COM_AUTODESK__POST_DEPRECATED_API)
enum {

  CIPOST_MAXIMUM_LOCALIZATION_TEXT_LENGTH = 1024,
  CIPOST_MAXIMUM_XML_TEXT_LENGTH = 16 * 1024
};
#endif

/**
  Localization callback.
 
  @param text The text.
  @param localizedText The localized text. The message must not exceed POST_MAXIMUM_LOCALIZATION_TEXT_LENGTH in length.

  Return POST_STATUS__OK.
*/
typedef unsigned int PREFIX(LocalizeCallback)(const wchar_t* text, wchar_t* localizedText);

/**
  Sets the global localization callback. This is not required.
*/
API unsigned int PREFIX(setLocalizeCallback)(PREFIX(LocalizeCallback) localizeCallback);

/**
  API usage callback.
 
  @param text The message.

  Return POST_STATUS__OK.
*/
typedef unsigned int PREFIX(APICallback)(const wchar_t* text);

/**
  Sets the global API usage callback. This is not required.
*/
API unsigned int PREFIX(setAPICallback)(PREFIX(APICallback) apiCallback);

/**
  Sets the language id. This is not required.
*/
API unsigned int PREFIX(setLangId)(const wchar_t* _langId);

} // end of extern

#if defined(_WIN32)
#pragma pack(pop)
#endif
