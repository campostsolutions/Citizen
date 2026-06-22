/**
  Copyright (C) 2012-2025 by Autodesk, Inc.
  All rights reserved.

  Doosan Lathe post processor configuration.

  $Revision: 44182 6b4e46a6aeacad3fc07571e7e410566fa13cb7b2 $
  $Date: 2025-06-13 13:05:29 $

  FORKID {C7A4BD6C-CF7A-4299-BF94-3C18351E8FA7}
*/

///////////////////////////////////////////////////////////////////////////////
//                        MANUAL NC COMMANDS
//
// The following ACTION commands are supported by this post.
//
//     partEject                  - Manually eject the part
//     transferType:phase,speed   - Phase or Speed spindle synchronization for stock-transfer
//     transferUseTorque:yes,no   - Use torque control for stock-transfer
//     usePolarInterpolation      - Force Polar interpolation mode for next operation (usePolarMode is deprecated but still supported)
//     usePolarCoordinates        - Force Polar coordinates for the next operation (useXZCMode is deprecated but still supported)
//     useTailStock:yes,no        - Use tailstock until canceled
//     syncSpindleStart:error, unclamp, speed   - Method to use when starting the spindle while they are connected/synched
//
///////////////////////////////////////////////////////////////////////////////

description = "Citizen Miyano ABX 80-THY with Mitsubishi control";
vendor = "Citizen Miyano";
vendorUrl = "https://citizenmachinery.co.uk/";
legal = "Copyright (C) 2012-2025 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45909;

longDescription = "Interface ABX 80-THY with Akart CNC Wizard";
capabilities = CAPABILITY_MILLING | CAPABILITY_TURNING | CAPABILITY_SETUP_SHEET;
mimetype = "text/html";
keywords = "MODEL_IMAGE PREVIEW_IMAGE PREVIEW_IMAGE_ALWAYS";

extension = "txt";
//programNameIsInteger = true;
setCodePage("utf-8");

//capabilities = CAPABILITY_MILLING | CAPABILITY_TURNING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(120); // reduced sweep due to G112 support
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
allowSpiralMoves = false;
allowFeedPerRevolutionDrilling = true;
highFeedrate = (unit == IN) ? 235 : 6000;

// removed and set from normal properties
useYAxisForDrilling = true;
gotSecondarySpindle = true;
gotMultiTurret = true;
reverseAxes = false;
xAxisMinimum = 0;
reverseSpindle = false;
usePartCatcher = false;
partCatcherPosition = 0;
gotChipConveyor = false;
maxTool = 32;
//maximumSpindleSpeed = 6000
autoEject = false;
useTailStock = false;
useTailStockTorque = 0;
useTailStockPositioning = "offset";
homeMethodZ = "G28";
homePositionZ = 0;
useG53ForXfer = "G53";
useG0 = false;
transferType = "phase";
optimizeCAxisSelect = false;
transferUseTorque = false;
cutoffConfirmation = false;
useSimpleThread = true;
useYAxisForDrilling = false;
useG400 = false;
looping = false;
numberOfRepeats = 1;
writeVersion = true;
seperateWordsWithSpace = true;
showNotes = false;
writeMachine = false;
writeTools = false;
useExtendedOffsets = "default";
useTCP = false;
properties.useCycles = true;

// user-defined properties
properties = {
  miyano_showSequenceNumbers    : false, // show sequence numbers
  miyano_sequenceNumberStart    : 1, // first sequence number
  miyano_sequenceNumberIncrement: 1, // increment for sequence numbers
  miyano_optionalStop           : true, // optional stop
  miyano_useRadius              : true, // specifies that arcs should be output using the radius (R word) instead of the I, J, and K words.
  miyano_maximumSpindleSpeed    : 6000, // specifies the maximum spindle speed
  miyano_maximumSpindleSpeed2   : 6000, // specifies the maximum spindle speed for spindle 2
  miyano_useParametricFeed      : true, // specifies that feed should be output using Q values
  miyano_leaveSpindleRunning    : true,
  miyano_subroutineAll          : false,
  miyano_speederFitted          : false
};

propertyDefinitions = {
  miyano_showSequenceNumbers    : {title:"Use sequence numbers", description:"Use sequence numbers for each block of outputted code.", group:1, type:"boolean"},
  miyano_sequenceNumberStart    : {title:"Start sequence number", description:"The number at which to start the sequence numbers.", group:1, type:"integer"},
  miyano_sequenceNumberIncrement: {title:"Sequence number increment", description:"The amount by which the sequence number is incremented by in each block.", group:1, type:"integer"},
  miyano_optionalStop           : {title:"Optional stop", description:"Outputs optional stop code during when necessary in the code.", type:"boolean"},
  miyano_useRadius              : {title:"Radius arcs", description:"If yes is selected, arcs are outputted using radius values rather than IJK.", type:"boolean"},
  miyano_maximumSpindleSpeed    : {title:"Max spindle speed", description:"Defines the maximum spindle speed allowed by your machines.", type:"integer", range:[0, 999999999]},
  miyano_maximumSpindleSpeed2   : {title:"Max spindle speed 2", description:"Defines the maximum spindle speed allowed by your machines for spindle 2.", type:"integer", range:[0, 999999999]},
  miyano_useParametricFeed      : {title:"Parametric feed", description:"Specifies the feed value that should be output using a Q value.", type:"boolean"},
  miyano_subroutineAll          : {title:"Subroutine all Operations", description:"Specifies whether the code should be output useable as sub programs for drip feeding", type:"boolean"},
  miyano_leaveSpindleRunning    : {title:"Leave Spindles Running", description:"Leave Spindles Running at the end of each Toolpath?", group:0, type:"boolean"},
  miyano_speederFitted          : {title:"Speeder Fitted", description:"Speeder Fitted, ignore MAX RPM Driven Tools", group:0, type:"boolean"}
};

// wcs definiton
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"Standard", format:"G", range:[54, 59]}
  ]
};

var singleLineCoolant = false; // specifies to output multiple coolant codes in one line rather than in separate lines
// samples:
// {id: COOLANT_THROUGH_TOOL, on: 88, off: 89}
// {id: COOLANT_THROUGH_TOOL, on: [8, 88], off: [9, 89]}
// {id: COOLANT_THROUGH_TOOL, turret1:{on: [8, 88], off:[9, 89]}, turret2:{on:88, off:89}}
// {id: COOLANT_THROUGH_TOOL, spindle1:{on: [8, 88], off:[9, 89]}, spindle2:{on:88, off:89}}
// {id: COOLANT_THROUGH_TOOL, spindle1t1:{on: [8, 88], off:[9, 89]}, spindle1t2:{on:88, off:89}}
// {id: COOLANT_THROUGH_TOOL, on: "M88 P3 (myComment)", off: "M89"}
var coolants = [
  {id:COOLANT_FLOOD, on:8, off:9},
  {id:COOLANT_MIST, on:138, off:139},
  {id:COOLANT_THROUGH_TOOL, spindle1:{on:108, off:109}, spindle2:{on:126, off:127}, spindleLive:{on:308, off:309}},
  {id:COOLANT_AIR, spindle1:{on:14, off:15}, spindle2:{on:114, off:115}},
  {id:COOLANT_AIR_THROUGH_TOOL},
  {id:COOLANT_SUCTION, on:7, off:9},
  {id:COOLANT_FLOOD_MIST},
  {id:COOLANT_FLOOD_THROUGH_TOOL},
  {id:COOLANT_OFF, off:9}
];

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-/";

var gFormat = createFormat({prefix:"G", decimals:1});
var mFormat = createFormat({prefix:"M", decimals:0});
var spatialFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_REAL});
var xFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_REAL, scale:2}); // diameter mode & IS SCALING POLAR COORDINATES
var yFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_REAL});
var zFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_REAL});
var rFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_REAL}); // radius
var abcFormat = createFormat({decimals:3, type:FORMAT_REAL, scale:DEG});
var bFormat = createFormat({prefix:"(B=", suffix:")", decimals:3, type:FORMAT_REAL, scale:DEG});
var cFormat = createFormat({decimals:3, type:FORMAT_REAL, scale:DEG});
var fpmFormat = createFormat({decimals:(unit == MM ? 2 : 3), type:FORMAT_REAL});
var fprFormat = createFormat({type:FORMAT_REAL, decimals:(unit == MM ? 3 : 4), minimum:(unit == MM ? 0.001 : 0.0001)});
var feedFormat = fpmFormat;
var pitchFormat = createFormat({decimals:6, type:FORMAT_REAL});
var toolFormat = createFormat({decimals:0, minDigitsLeft:4});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, type:FORMAT_REAL}); // seconds - range 0.001-99999.999
var milliFormat = createFormat({decimals:0}); // milliseconds // range 1-9999
var taperFormat = createFormat({decimals:1, scale:DEG});
var threadP1Format = createFormat({decimals:0, minDigitsLeft:6});
var threadPQFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_LZS, minDigitsLeft:0, minDigitsRight:1});
var dwellFormat = createFormat({prefix:"U", decimals:3});
// var peckFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_REAL});
var peckFormat = createFormat({decimals:(unit == MM ? 3 : 4), type:FORMAT_LZS, minDigitsLeft:0, minDigitsRight:(unit == MM ? 3 : 4)});
var dFormat = createFormat({prefix:"D", width:3, zeropad:true}); // used with TCP code (G700)
var oFormat = createFormat({decimals:0, minDigitsLeft:4});

var xOutput = createOutputVariable({prefix:"X"}, xFormat);
var yOutput = createOutputVariable({prefix:"Y"}, yFormat);
var zOutput = createOutputVariable({prefix:"Z"}, zFormat);
var aOutput = createOutputVariable({prefix:"A"}, abcFormat);
var bOutput = createOutputVariable({}, bFormat);
var cOutput = createOutputVariable({prefix:"C"}, cFormat);
var subOutput = createOutputVariable({prefix:"B", control:CONTROL_FORCE}, spatialFormat);
var feedOutput = createOutputVariable({prefix:"F"}, feedFormat);
var pitchOutput = createOutputVariable({prefix:"F", control:CONTROL_FORCE}, pitchFormat);
var sOutput = createOutputVariable({prefix:"S", control:CONTROL_FORCE}, rpmFormat);
var pOutput = createOutputVariable({prefix:"P", control:CONTROL_FORCE}, rpmFormat);
var spOutput = createOutputVariable({prefix:"P", control:CONTROL_FORCE}, rpmFormat);
var rOutput = createOutputVariable({prefix:"R", control:CONTROL_FORCE}, rFormat);
var peckOutput = createOutputVariable({prefix:"Q", control:CONTROL_FORCE}, peckFormat);

// cycle thread output
var threadP1Output = createOutputVariable({prefix:"P", control:CONTROL_FORCE}, threadP1Format);
var threadP2Output = createOutputVariable({prefix:"P", control:CONTROL_FORCE}, threadPQFormat);
var threadQOutput = createOutputVariable({prefix:"Q", control:CONTROL_FORCE}, threadPQFormat);
var threadROutput = createOutputVariable({prefix:"R", control:CONTROL_FORCE}, threadPQFormat);
var g92ROutput = createOutputVariable({prefix:"R", control:CONTROL_FORCE}, zFormat); // no scaling

// circular output
var iOutput = createOutputVariable({prefix:"I", control:CONTROL_FORCE}, spatialFormat);
var jOutput = createOutputVariable({prefix:"J", control:CONTROL_FORCE}, spatialFormat);
var kOutput = createOutputVariable({prefix:"K", control:CONTROL_FORCE}, spatialFormat);
var outputDocuments = [];
var gMotionModal = createOutputVariable({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createOutputVariable({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gFeedModeModal = createOutputVariable({}, gFormat); // modal group 5 // G98-99
var gSpindleModeModal = createOutputVariable({}, gFormat); // modal group 5 // G96-97
var gUnitModal = createOutputVariable({}, gFormat); // modal group 6 // G20-21
var gCycleModal = createOutputVariable({}, gFormat); // modal group 9 // G81, ...
var gPolarModal = createOutputVariable({}, gFormat); // G12.1, G13.1
var cAxisBrakeModal = createOutputVariable({}, mFormat);
var mInterferModal = createOutputVariable({}, mFormat);
var cAxisEngageModal = createOutputVariable({}, mFormat);
var gWCSModal = createOutputVariable({}, gFormat);
var tailStockModal = createOutputVariable({}, mFormat);
var mTappingModal = createOutputVariable({}, mFormat);

// fixed settings
var firstFeedParameter = 100;
var airCleanChuck = true; // use air to clean off chuck at part transfer and part eject

// defined in defineMachine
var turret1GotYAxis;
var turret2GotYAxis;
var gotYAxis;
var yAxisMinimum;
var yAxisMaximum;
var xAxisMinimum;
var gotBAxis;
var bAxisIsManual;
var gotMultiTurret;
var gotPolarInterpolation;
var gotSecondarySpindle;
var gotDoorControl;
var useMultiAxisFeatures;
var useCAxisSelectWithTurning;

var WARNING_TURRET_UNSPECIFIED = 0;

var SPINDLE_MAIN = 0;
var SPINDLE_SUB = 1;
var SPINDLE_LIVE = 2;

var TRANSFER_PHASE = 0;
var TRANSFER_SPEED = 1;
var TRANSFER_STOP = 2;

// getSpindle parameters
var TOOL = false;
var PART = true;

// moveSubSpindle parameters
var HOME = 0;
var RAPID = 1;
var FEED = 2;
var TORQUE = 3;

// synchronized spindle start parameters
var SYNC_ERROR = 0;
var SYNC_UNCLAMP = 1;
var SYNC_SPEED = 2;

// clampChuck parameters
var CLAMP = true;
var UNCLAMP = false;

// collected state
var sequenceNumber;
var currentWorkOffset;
var optionalSection = false;
var forceSpindleSpeed = false;
var activeMovements; // do not use by default
var currentFeedId;
var previousSpindle = SPINDLE_MAIN;
var activeSpindle = SPINDLE_MAIN;
//var partCutoff = false;
//var transferType;
//var transferUseTorque;
var barOutput = createVariable({prefix:"B", force:true}, spatialFormat);
var showSequenceNumbers;
var forcePolarCoordinates = false; // forces Polar coordinate output, activated by Action:usePolarCoordinates
var forcePolarInterpolation = false; // force Polar interpolation output, activated by Action:usePolarInterpolation
var forceTailStock = false; // enable/disable TailStock
var tapping = false;
var ejectRoutine = false;
var bestABC = undefined;
var headOffset = 0;
var lastSpindleMode = undefined;
var lastSpindleSpeed = 0;
var lastSpindleDirection = undefined;
var syncStartMethod = SYNC_ERROR; // method used to output spindle block when they are already synched/connected
var activeTurret = 1;
var transferOrientation; // spindle orientation during part transfers
var forceTurningMode = false; // used to force turning mode in onSection after part transfer
var offsetFactor;  // 100 if not using extended offset, 1000 otherwise
var useExtendedOffsets;
var turret1GotBAxis;  // for storing the initial state of the gotBAxis variable, when switching turret.
var reverseAxes;
var currentToolCode; // active tool number + offset
var modelType; // model type of machine
var operationSupportsTCP; // multi-axis operation supports TCP
var previousMaximumSpeed = 0;
var reverseTap = false;
var debugMode = false;
var base64encoded = true;
var gSpindleModal = createModal({}, mFormat);
var machineState = {
  isTurningOperation            : undefined,
  liveToolIsActive              : undefined,
  cAxisIsEngaged                : undefined,
  machiningDirection            : undefined,
  mainSpindleIsActive           : undefined,
  subSpindleIsActive            : undefined,
  mainSpindleBrakeIsActive      : undefined,
  subSpindleBrakeIsActive       : undefined,
  tailstockIsActive             : false,
  usePolarInterpolation         : false,
  usePolarCoordinates           : false,
  axialCenterDrilling           : false,
  currentBAxisOrientationTurning: new Vector(0, 0, 0),
  mainChuckIsClamped            : undefined,
  subChuckIsClamped             : undefined,
  spindlesAreAttached           : false,
  spindlesAreSynchronized       : false,
  stockTransferIsActive         : false,
  cAxesAreSynchronized          : false,
  feedPerRevolution             : undefined
};

var mainSpindleAxisName = ["SP1", 1]; // axis name, axis number (number is used for eg. SETMS(VALUE));
var subSpindleAxisName = ["SP2", 2]; // axis name, axis number (number is used for eg. SETMS(VALUE));
var liveToolSpindleAxisName = ["SP3", 3]; // axis name, axis number (number is used for eg. SETMS(VALUE));

/** G/M codes setup */
function getCode(code, spindle) {
  switch (code) {
  case "PART_CATCHER_ON":
    return 10;
  case "PART_CATCHER_OFF":
    return 11;
  case "TAILSTOCK_ON":
    machineState.tailstockIsActive = true;
    return 78;
  case "TAILSTOCK_OFF":
    machineState.tailstockIsActive = false;
    return 79;
  case "TAILSTOCK_CONTROL_ON":
    return 300;
  case "TAILSTOCK_CONTROL_OFF":
    return 301;
    /*
  case "SET_SPINDLE_FRAME":
    return (spindle == SPINDLE_MAIN) ? 80 : 83; // M80 is related to the tool setter arm moves
*/
  case "FEED_MODE_MM_REV":
    return 99;
  case "FEED_MODE_MM_MIN":
    return 98;
  case "ENABLE_C_AXIS":
    machineState.cAxisIsEngaged = true;
    return (spindle == SPINDLE_MAIN) ? 13 : 113;
  case "DISABLE_C_AXIS":
    machineState.cAxisIsEngaged = false;
    return (spindle == SPINDLE_MAIN) ? 14 : 114;
  case "POLAR_INTERPOLATION_ON":
    return 12.1;
  case "POLAR_INTERPOLATION_OFF":
    return 13.1;
  case "STOP_SPINDLE":
    switch (spindle) {
    case SPINDLE_MAIN:
      return 455;
    case SPINDLE_LIVE:
      return [5, 45];
    case SPINDLE_SUB:
      return 465;
    }

    break;
  case "ORIENT_SPINDLE":
    return (spindle == SPINDLE_MAIN) ? 19 : 119;
  case "START_SPINDLE_CW":
    switch (spindle) {
    case SPINDLE_MAIN:
      return 3;
    case SPINDLE_LIVE:
      return 43;
    case SPINDLE_SUB:
      return properties.reverseSpindle ? 104 : 103;
    }
    break;
  case "START_SPINDLE_CCW":
    switch (spindle) {
    case SPINDLE_MAIN:
      return 4;
    case SPINDLE_LIVE:
      return 44;
    case SPINDLE_SUB:
      return properties.reverseSpindle ? 103 : 104;
    }

    break;
  case "FEED_MODE_UNIT_REV":
    machineState.feedPerRevolution = true;
    return 99;
  case "FEED_MODE_UNIT_MIN":
    machineState.feedPerRevolution = false;
    return 98;
  case "CONSTANT_SURFACE_SPEED_ON":
    return 96;
  case "CONSTANT_SURFACE_SPEED_OFF":
    return 97;
  case "AUTO_AIR_ON":
    return 14;
  case "AUTO_AIR_OFF":
    return 15;
  case "LOCK_MULTI_AXIS":
    return (spindle == SPINDLE_MAIN) ? 89 : 189;
  case "UNLOCK_MULTI_AXIS":
    return (spindle == SPINDLE_MAIN) ? 90 : 190;
  case "CLAMP_CHUCK":
    return (spindle == SPINDLE_MAIN) ? 68 : 168;
  case "UNCLAMP_CHUCK":
    return (spindle == SPINDLE_MAIN) ? 69 : 169;
  case "SPINDLE_SYNCHRONIZATION_PHASE":
    machineState.spindlesAreSynchronized = true;
    return 213;
  case "SPINDLE_SYNCHRONIZATION_SPEED":
    machineState.spindlesAreSynchronized = true;
    return 203;
  case "SPINDLE_SYNCHRONIZATION_OFF":
    machineState.spindlesAreSynchronized = false;
    return 205;
  case "CONNECT_C_AXES":
    machineState.cAxesAreSynchronized = true;
    return 136;
  case "DISCONNECT_C_AXES":
    machineState.cAxesAreSynchronized = false;
    return 137;
  case "TORQUE_SKIP_ON":
    return 86;
  case "TORQUE_SKIP_OFF":
    return 87;
  case "SELECT_SPINDLE":
    switch (spindle) {
    case SPINDLE_MAIN:
      machineState.mainSpindleIsActive = true;
      machineState.subSpindleIsActive = false;
      machineState.liveToolIsActive = false;
      return 11;
    case SPINDLE_LIVE:
      machineState.mainSpindleIsActive = false;
      machineState.subSpindleIsActive = false;
      machineState.liveToolIsActive = true;
      if (currentSection.getTool().getTurret() == 2 || currentSection.getTool().getTurret() == 0 ) {
        return 12;
      } else if (currentSection.getTool().getTurret() == 1) {
        return 22;
      } else {
        return 32;
      }
    case SPINDLE_SUB:
      machineState.mainSpindleIsActive = false;
      machineState.subSpindleIsActive = true;
      machineState.liveToolIsActive = false;
      return 21;

    }
    break;
  case "RIGID_TAPPING":
    return 29;
  case "INTERLOCK_BYPASS":
    return (spindle == SPINDLE_MAIN) ? 31 : 131;
  case "INTERFERENCE_CHECK_OFF":
    return 110;
  case "INTERFERENCE_CHECK_ON":
    return 111;
  case "YAXIS_INTERLOCK_RELEASE_ON":
    return 272;
  case "YAXIS_INTERLOCK_RELEASE_OFF":
    return 273;
  case "CYCLE_PART_EJECTOR":
    return 116;
  case "AIR_BLAST_ON":
    return (spindle == SPINDLE_MAIN) ? 14 : 114;
  case "AIR_BLAST_OFF":
    return (spindle == SPINDLE_MAIN) ? 15 : 115;
  default:
    error(localize("Command " + code + " is not defined."));
    return 0;
  }
  return 0;
}

function getImagePath(comment, id) {
  const imageName = comment + id + ".png";
  if (FileSystem.isFile(FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), imageName))) {
    return imageName;
  }
  return "placeholder.png";
}
var sectionObject = {};

function redirectSection() {
  sectionObject = {
    ncLocation : FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), formatText(getParameter("operation-comment") + currentSection.getId()) + ".nc"),
    tool       : tool,
    name       : formatText((hasParameter("operation-comment") ? getParameter("operation-comment") : getParameter("operation-strategy")) + (groupedOperations ? " (Grouped operations)" : "")),
    type       : formatText(getParameter("operation-strategy")),
    spindle    : getSpindle(true) == SPINDLE_SUB ? "Sub spindle" : "Main spindle",
    spindleType: currentSection.getType() == TYPE_MILLING ? "live tool" : "turning",
    image      : formatText(getImagePath(getParameter("operation-comment"), getParameter("autodeskcam:operation-id"))),
    setupName  : formatText(getSetupName(getParameter("autodeskcam:path")))
  };
  outputDocuments.push(sectionObject);

  if (!debugMode) {
    redirectToFile(sectionObject.ncLocation);
  } else {
    writeBlock(sectionObject.ncLocation);
    writeComment("******************REDIRECT HERE******************");
  }

}

/**  Returns the desired tolerance for the given section in MM.*/
function getTolerance() {
  var t1 = toPreciseUnit(tolerance, MM);
  var t2 = getParameter("operation:tolerance", t1);
  t1 = t1 > 0 ? Math.min(t1, t2) : t2;
  return unit == IN ? t1 * 25.4 : t1;
}

function formatSequenceNumber() {
  if (sequenceNumber > 99999) {
    sequenceNumber = properties.miyano_sequenceNumberStart;
  }
  var seqno = "N" + sequenceNumber;
  sequenceNumber += properties.miyano_sequenceNumberIncrement;
  return seqno;
}

/**
  Writes the specified block.
*/
function writeBlock() {
  var text = formatWords(arguments);
  if (!text) {
    return;
  }
  var seqno = "";
  var opskip = "";
  if (showSequenceNumbers == "true") {
    seqno = formatSequenceNumber();
  }
  if (optionalSection) {
    opskip = "/";
  }
  if (text) {
    writeWords(opskip, seqno, text);
  }
}

function formatComment(text) {
  return "(" + String(filterText(String(text).toUpperCase(), permittedCommentChars)).replace(/[()]/g, "") + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function getB(abc, section) {
  if (section.spindle == SPINDLE_PRIMARY) {
    return abc.y;
  } else {
    return Math.PI - abc.y;
  }
}

function writeCommentSeqno(text) {
  writeln(formatSequenceNumber() + formatComment(text));
}

function defineMachine() {
  gotSecondarySpindle = true;
  gotMultiTurret = true;
  turret1GotYAxis = true;
  turret2GotYAxis = true;
  turret3GotYAxis = true
  modelType = "ABX-80THY";
  turret1GotYAxis = true;
  yAxisMinimum = toPreciseUnit(-40, MM); // specifies the minimum range for the Y-axis
  yAxisMaximum = toPreciseUnit(40, MM); // specifies the maximum range for the Y-axis
  xAxisMinimum = toPreciseUnit(-5, MM); // specifies the maximum range for the X-axis (RADIUS MODE VALUE)
  gotBAxis = false; // B-axis always requires customization to match the machine specific functions for doing rotations
  bAxisIsManual = false; // B-axis is manually set and not programmable
  gotPolarInterpolation = true; // specifies if the machine has XY polar interpolation capabilities
  gotDoorControl = false;
  useCAxisSelectWithTurning = false;
  useMultiAxisFeatures = false;
  useExtendedOffsets = properties.useExtendedOffsets == "default" ? "main" : properties.useExtendedOffsets;

  // define B-axis
  if (gotBAxis) {
    if (bAxisIsManual) {
      bFormat.setPrefix("(B=");
      bFormat.setSuffix(")");
      bOutput.setFormat(bFormat);
      gWCSModal.format(69.1);
    } else {
      bFormat.setPrefix("B");
      bFormat.setSuffix("");
      bOutput.setFormat(bFormat);
      subOutput.setPrefix("A");
      gWCSModal.format(369);
    }
  }
}

function activateMachine(section) {
  // TCP setting
  //operationSupportsTCP = section.isMultiAxis();// && getProperty("useTCP");

  // handle multiple turrets
  var turret = 1;
  if (gotMultiTurret) {
    turret = section.getTool().turret;
    if (turret == 0) {
      //warning(localize("Turret has not been Declared - Please Select a Turret for the Tool"));
      turret = 1; // upper turret as default
    }
    turret = turret == undefined ? 1 : turret;
    switch (turret) {
    case 1:
      gotYAxis = turret1GotYAxis;
      gotBAxis = false;
      break;
    case 2:
      gotYAxis = turret2GotYAxis;
      gotBAxis = false;
      break;
    case 3:
      gotYAxis = turret3GotYAxis;
      gotBAxis = false;
      break;
    default:
      warning(subst(localize("Turret %1 is not supported, Please select turrets 1 - 3"), turret));
      return turret;
    }
  } else {
    gotYAxis = turret1GotYAxis;
  }

  // disable unsupported rotary axes output
  if (!gotYAxis) {
    yOutput.disable();
  }
  aOutput.disable();

  // define machine configuration
  var bAxis;
  var cAxis;
  if (section.getSpindle() == SPINDLE_PRIMARY) {
    bAxis = createAxis({coordinate:1, table:false, axis:[0, -1, 0], range:[-90, 45], preference:0, tcp:false});
    cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], cyclic:true, range:[-99999, 99999], reset:1, preference:0, tcp:true});
  } else {
    bAxis = createAxis({coordinate:1, table:false, axis:[0, 1, 0], range:[-45, 90], preference:0, tcp:true});
    cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], range:[-99999, 99999], cyclic:true, reset:1, preference:1, tcp:true});
  }
  if (gotBAxis) {
    machineConfiguration = new MachineConfiguration(bAxis, cAxis);
    bOutput.enable();
  } else {
    machineConfiguration = new MachineConfiguration(cAxis);
    bOutput.disable();
  }
  bOutput.disable();
  // define spindle axis
  if (!gotBAxis || bAxisIsManual || (turret == 1)) {
    if ((getMachiningDirection(section) == MACHINING_DIRECTION_AXIAL) && !section.isMultiAxis()) {
      machineConfiguration.setSpindleAxis(new Vector(0, 0, 1));
    } else {
      machineConfiguration.setSpindleAxis(new Vector(1, 0, 0));
    }
  } else {
    machineConfiguration.setSpindleAxis(new Vector(1, 0, 0)); // set the spindle axis depending on B0 orientation
  }

  // define linear axes limits
  var xAxisMaximum = 10000; // don't check X-axis maximum limit
  yAxisMinimum = gotYAxis ? yAxisMinimum : 0;
  yAxisMaximum = gotYAxis ? yAxisMaximum : 0;
  var xAxis = createAxis({actuator:"linear", coordinate:0, table:true, axis:[1, 0, 0], range:[xAxisMinimum, xAxisMaximum]});
  var yAxis = createAxis({actuator:"linear", coordinate:1, table:true, axis:[0, 1, 0], range:[yAxisMinimum, yAxisMaximum]});
  var zAxis = createAxis({actuator:"linear", coordinate:2, table:true, axis:[0, 0, 1], range:[-100000, 100000]});
  machineConfiguration.setAxisX(xAxis);
  machineConfiguration.setAxisY(yAxis);
  machineConfiguration.setAxisZ(zAxis);

  // enable retract/reconfigure
  safeRetractDistance = (unit == IN) ? 1 : 25; // additional distance to retract out of stock, can be overridden with a property
  safeRetractFeed = (unit == IN) ? 20 : 500; // retract feed rate
  safePlungeFeed = (unit == IN) ? 10 : 250; // plunge feed rate
  var stockExpansion = new Vector(toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN)); // expand stock XYZ values
  machineConfiguration.enableMachineRewinds();
  machineConfiguration.setSafeRetractDistance(safeRetractDistance);
  machineConfiguration.setSafeRetractFeedrate(safeRetractFeed);
  machineConfiguration.setSafePlungeFeedrate(safePlungeFeed);
  machineConfiguration.setRewindStockExpansion(stockExpansion);

  // multi-axis feedrates
  machineConfiguration.setMultiAxisFeedrate(
    operationSupportsTCP ? FEED_FPM : FEED_DPM, // FEED_INVERSE_TIME,
    99999, // maximum output value for dpm feed rates
    DPM_COMBINATION, // INVERSE_MINUTES/INVERSE_SECONDS or DPM_COMBINATION/DPM_STANDARD
    0.5, // tolerance to determine when the DPM feed has changed
    unit == MM ? 1.0 : 1.0 // ratio of rotary accuracy to linear accuracy for DPM calculations
  );

  machineConfiguration.setVendor("Citizen Miyano");
  machineConfiguration.setModel(modelType);
  setMachineConfiguration(machineConfiguration);
  if (section.isMultiAxis()) {
    section.optimizeMachineAnglesByMachine(machineConfiguration, OPTIMIZE_AXIS);
  }

  return turret;
}
function verifyProps() {
  if (typeof properties.miyano_sequenceNumbers == "string") {
    if (properties.miyano_sequenceNumbers.toLowerCase() == "false") {
      properties.miyano_sequenceNumbers = false;
    } else {
      properties.miyano_sequenceNumbers = true;
    }
  }
  if (typeof properties.miyano_optionalStop == "string") {
    if (properties.miyano_optionalStop.toLowerCase() == "false") {
      properties.miyano_optionalStop = false;
    } else {
      properties.miyano_optionalStop = true;
    }
  }
  if (typeof properties.miyano_useRadius == "string") {
    if (properties.miyano_useRadius.toLowerCase() == "false") {
      properties.miyano_useRadius = false;
    } else {
      properties.miyano_useRadius = true;
    }
  }

  if (typeof properties.miyano_subroutineAll == "string") {
    if (properties.miyano_subroutineAll.toLowerCase() == "false") {
      properties.miyano_subroutineAll = false;
    } else {
      properties.miyano_subroutineAll = true;
    }
  }

  if (typeof properties.miyano_useParametricFeed == "string") {
    if (properties.miyano_useParametricFeed.toLowerCase() == "false") {
      properties.miyano_useParametricFeed = false;
    } else {
      properties.miyano_useParametricFeed = true;
    }
  }

  if (typeof properties.miyano_leaveSpindleRunning == "string") {
    if (properties.miyano_leaveSpindleRunning.toLowerCase() == "false") {
      properties.miyano_leaveSpindleRunning = false;
    } else {
      properties.miyano_leaveSpindleRunning = true;
    }
  }
}
function onOpen() {
  verifyProps();
  if (properties.miyano_useRadius) {
    maximumCircularSweep = toRad(90); // avoid potential center calculation errors for CNC
  }

  // Copy certain properties into global variables
  showSequenceNumbers = properties.miyano_sequenceNumbers;
  /* transferType = parseToggle(getProperty("transferType"), "PHASE", "SPEED");
   if (transferType == undefined) {
     error(localize("TransferType must be Phase or Speed"));
     return;
   }*/
  // transferUseTorque = getProperty("transferUseTorque");
  //setProperty("useTailStockPosition", (getProperty("useTailStockPositioning") == "offset" && getProperty("useTailStockPosition") == 0) ? toPreciseUnit(0.25, IN) : getProperty("useTailStockPosition"));

  // Setup default M-codes
  mInterferModal.format(getCode("INTERFERENCE_CHECK_ON", SPINDLE_MAIN));
  mTappingModal.format(177); // reverse tapping off

  // define machine
  defineMachine();
  turret1GotBAxis = gotBAxis;
  activeTurret = activateMachine(getSection(0));

  if (highFeedrate <= 0) {
    error(localize("You must set 'highFeedrate' because axes are not synchronized for rapid traversal."));
    return;
  }

  //reverseAxes = reverseAxes, false;

  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.miyano_sequenceNumberStart;
  //  writeln("%");

  /* if (programName) {
     var programId;
     try {
       programId = getAsInt(programName);
     } catch (e) {
       error(localize("Program name must be a number."));
       return;
     }
     if (!((programId >= 1) && (programId <= 9999))) {
       error(localize("Program number is out of range."));
       return;
     }
     if (programComment) {
       writeln("O" + oFormat.format(programId) + " (" + filterText(String(programComment).toUpperCase(), permittedCommentChars) + ")");
     } else {
       writeln("O" + oFormat.format(programId));
     }
   } else {
     error(localize("Program name has not been specified."));
     return;
   }*/

  /* if (getProperty("writeVersion")) {
     if ((typeof getHeaderVersion == "function") && getHeaderVersion()) {
       writeComment(localize("post version") + ": " + getHeaderVersion());
     }
     if ((typeof getHeaderDate == "function") && getHeaderDate()) {
       writeComment(localize("post modified") + ": " + getHeaderDate());
     }
   }*/

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var mDescription = machineConfiguration.getDescription();

  /* if (getProperty("writeMachine") && (vendor || model || mDescription)) {
     writeComment(localize("Machine"));
     if (vendor) {
       writeComment("  " + localize("vendor") + ": " + vendor);
     }
     if (model) {
       writeComment("  " + localize("model") + ": " + model);
     }
     if (mDescription) {
       writeComment("  " + localize("description") + ": "  + mDescription);
     }
   }*/

  // dump tool information
  /*  if (getProperty("writeTools")) {
      var zRanges = {};
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        for (var i = 0; i < numberOfSections; ++i) {
          var section = getSection(i);
          var zRange = section.getGlobalZRange();
          var tool = section.getTool();
          if (zRanges[tool.number]) {
            zRanges[tool.number].expandToRange(zRange);
          } else {
            zRanges[tool.number] = zRange;
          }
        }
      }

      var tools = getToolTable();
      if (tools.getNumberOfTools() > 0) {
        for (var i = 0; i < tools.getNumberOfTools(); ++i) {
          var tool = tools.getTool(i);
          var toolOffsetFactor = getToolOffsetFactor(tool);
          toolFormat.setMinDigitsLeft(toolOffsetFactor == 1000 ? 5 : 4);
          var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
          var comment = "T" + toolFormat.format(tool.number * toolOffsetFactor + compensationOffset % toolOffsetFactor) + " " +
            "D=" + spatialFormat.format(tool.diameter) + " " +
            (tool.diameter != 0 ? "D=" + spatialFormat.format(tool.diameter) + " " : "") +
            (tool.isTurningTool() ? localize("NR") + "=" + spatialFormat.format(tool.noseRadius) : localize("CR") + "=" + spatialFormat.format(tool.cornerRadius)) +
            (tool.taperAngle > 0 && (tool.taperAngle < Math.PI) ? " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg") : "") +
            (zRanges[tool.number] ? " - " + localize("ZMIN") + "=" + spatialFormat.format(zRanges[tool.number].getMinimum()) : "") +
             " - " + localize(getToolTypeName(tool.type));
          writeComment(comment);
        }
      }
    }*/

  if (false) {
    // check for duplicate tool number
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var sectioni = getSection(i);
      var tooli = sectioni.getTool();
      for (var j = i + 1; j < getNumberOfSections(); ++j) {
        var sectionj = getSection(j);
        var toolj = sectionj.getTool();
        if (tooli.number == toolj.number) {
          if (spatialFormat.areDifferent(tooli.diameter, toolj.diameter) ||
            spatialFormat.areDifferent(tooli.cornerRadius, toolj.cornerRadius) ||
            abcFormat.areDifferent(tooli.taperAngle, toolj.taperAngle) ||
            (tooli.numberOfFlutes != toolj.numberOfFlutes)) {
            error(
              subst(
                localize("Using the same tool number for different cutter geometry for operation '%1' and '%2'."),
                sectioni.hasParameter("operation-comment") ? sectioni.getParameter("operation-comment") : ("#" + (i + 1)),
                sectionj.hasParameter("operation-comment") ? sectionj.getParameter("operation-comment") : ("#" + (j + 1))
              )
            );
            return;
          }
        }
      }
    }
  }

  // support program looping for bar work
  /* if (getProperty("looping")) {
     if (getProperty("numberOfRepeats") < 1) {
       error(localize("numberOfRepeats must be greater than 0."));
       return;
     }
     if (sequenceNumber == 1) {
       sequenceNumber++;
     }
     writeln("");
     writeln("");
     writeComment(localize("Local Looping"));
     writeln("");
     writeBlock(mFormat.format(98), "Q1", "L" + getProperty("numberOfRepeats"));
     onCommand(COMMAND_OPEN_DOOR);
     writeBlock(mFormat.format(30));
     writeln("");
     writeln("");
     writeln("N1 (START MAIN PROGRAM)");
   }*/

  /*  writeBlock(
      gFormat.format(0),
      gFormat.format(18),
      gUnitModal.format((unit == IN) ? 20 : 21),
      gFormat.format(40),
      gFormat.format(54),
      gFormat.format(80),
      gFormat.format(99),
      (conditional(gotSecondarySpindle, mFormat.format(getCode("INTERFERENCE_CHECK_OFF", SPINDLE_MAIN))))
    );
    onCommand(COMMAND_CLOSE_DOOR);
  */
  //if (getProperty("gotChipConveyor")) {
  //  onCommand(COMMAND_START_CHIP_TRANSPORT);
  //}

  // automatically eject part at end of program
  //if (getProperty("autoEject") != "false") {
  //   ejectRoutine = true;
  // }

  // determine starting spindle
  switch (getSection(0).spindle) {
  case SPINDLE_PRIMARY: // main spindle
    activeSpindle = SPINDLE_MAIN;
    machineState.mainChuckIsClamped = true;
    break;
  case SPINDLE_SECONDARY: // sub spindle
    activeSpindle = SPINDLE_SUB;
    machineState.subChuckIsClamped = true;
    break;
  }
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

function forceFeed() {
  currentFeedId = undefined;
  feedOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  forceFeed();
}

function forceUnlockMultiAxis() {
  cAxisBrakeModal.reset();
}

function forceModals() {
  if (arguments.length == 0) { // reset all modal variables listed below
    if (typeof gMotionModal != "undefined") {
      gMotionModal.reset();
    }
    if (typeof gPlaneModal != "undefined") {
      gPlaneModal.reset();
    }
    if (typeof gAbsIncModal != "undefined") {
      gAbsIncModal.reset();
    }
    if (typeof gFeedModeModal != "undefined") {
      gFeedModeModal.reset();
    }
  } else {
    for (var i in arguments) {
      arguments[i].reset(); // only reset the modal variable passed to this function
    }
  }
}

function getSpindleCode(section) {
  var livetool;
  if (section.spindle == SPINDLE_PRIMARY) { // mainspindle
    if (machineState.isTurningOperation || machineState.axialCenterDrilling) {
      return mainSpindleAxisName[1];
    } else {
      if (tool.number <= 12) {
        livetool = 3;
      } else {
        livetool = 4;
      }
      return livetool; // milling live tool
    }
  } else { // subspindle
    if (machineState.isTurningOperation || machineState.axialCenterDrilling) {
      return subSpindleAxisName[1];
    } else {
      if (tool.number <= 12) {
        livetool = 3;
      } else {
        livetool = 4;
      }
      return livetool; // milling live tool
    }
  }
}

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
}

function formatFeedMode(mode) {
  var fMode = (mode == FEED_PER_REVOLUTION || tapping) ? getCode("FEED_MODE_UNIT_REV") : getCode("FEED_MODE_UNIT_MIN");
  if (fMode) {
    feedFormat = mode == FEED_PER_REVOLUTION ? fprFormat : fpmFormat;
    feedOutput.setFormat(feedFormat);
  }
  return gFeedModeModal.format(fMode);
}

function getFeed(f) {
  if (currentSection.feedMode != FEED_PER_REVOLUTION && machineState.feedPerRevolution) {
    f /= spindleSpeed;
  }
  if (activeMovements) {
    var feedContext = activeMovements[movement];
    if (feedContext != undefined) {
      if (!feedFormat.areDifferent(feedContext.feed, f)) {
        if (feedContext.id == currentFeedId) {
          return ""; // nothing has changed
        }
        forceFeed();
        currentFeedId = feedContext.id;
        return "F#" + (firstFeedParameter + feedContext.id);
      }
    }
    currentFeedId = undefined; // force Q feed next time
  }
  return feedOutput.format(f); // use feed value
}

function initializeActiveFeeds() {
  activeMovements = new Array();
  var movements = currentSection.getMovements();
  var feedPerRev = currentSection.feedMode == FEED_PER_REVOLUTION;

  var id = 0;
  var activeFeeds = new Array();
  if (hasParameter("operation:tool_feedCutting")) {
    if (movements & ((1 << MOVEMENT_CUTTING) | (1 << MOVEMENT_LINK_TRANSITION) | (1 << MOVEMENT_EXTENDED))) {
      var feedContext = new FeedContext(id, localize("Cutting"), feedPerRev ? getParameter("operation:tool_feedCuttingRel") : getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_CUTTING] = feedContext;
      if (!hasParameter("operation:tool_feedTransition")) {
        activeMovements[MOVEMENT_LINK_TRANSITION] = feedContext;
      }
      activeMovements[MOVEMENT_EXTENDED] = feedContext;
    }
    ++id;
    if (movements & (1 << MOVEMENT_PREDRILL)) {
      feedContext = new FeedContext(id, localize("Predrilling"), feedPerRev ? getParameter("operation:tool_feedCuttingRel") : getParameter("operation:tool_feedCutting"));
      activeMovements[MOVEMENT_PREDRILL] = feedContext;
      activeFeeds.push(feedContext);
    }
    ++id;
  }

  if (hasParameter("operation:finishFeedrate")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var finishFeedrateRel;
      if (hasParameter("operation:finishFeedrateRel")) {
        finishFeedrateRel = getParameter("operation:finishFeedrateRel");
      } else if (hasParameter("operation:finishFeedratePerRevolution")) {
        finishFeedrateRel = getParameter("operation:finishFeedratePerRevolution");
      }
      var feedContext = new FeedContext(id, localize("Finish"), feedPerRev ? finishFeedrateRel : getParameter("operation:finishFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), feedPerRev ? getParameter("operation:tool_feedCuttingRel") : getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedEntry")) {
    if (movements & (1 << MOVEMENT_LEAD_IN)) {
      var feedContext = new FeedContext(id, localize("Entry"), feedPerRev ? getParameter("operation:tool_feedEntryRel") : getParameter("operation:tool_feedEntry"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_IN] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LEAD_OUT)) {
      var feedContext = new FeedContext(id, localize("Exit"), feedPerRev ? getParameter("operation:tool_feedExitRel") : getParameter("operation:tool_feedExit"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_OUT] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:noEngagementFeedrate")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), feedPerRev ? getParameter("operation:noEngagementFeedrateRel") : getParameter("operation:noEngagementFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting") &&
    hasParameter("operation:tool_feedEntry") &&
    hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(
        id,
        localize("Direct"),
        Math.max(
          feedPerRev ? getParameter("operation:tool_feedCuttingRel") : getParameter("operation:tool_feedCutting"),
          feedPerRev ? getParameter("operation:tool_feedEntryRel") : getParameter("operation:tool_feedEntry"),
          feedPerRev ? getParameter("operation:tool_feedExitRel") : getParameter("operation:tool_feedExit")
        )
      );
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:reducedFeedrate")) {
    if (movements & (1 << MOVEMENT_REDUCED)) {
      var feedContext = new FeedContext(id, localize("Reduced"), feedPerRev ? getParameter("operation:reducedFeedrateRel") : getParameter("operation:reducedFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_REDUCED] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedRamp")) {
    if (movements & ((1 << MOVEMENT_RAMP) | (1 << MOVEMENT_RAMP_HELIX) | (1 << MOVEMENT_RAMP_PROFILE) | (1 << MOVEMENT_RAMP_ZIG_ZAG))) {
      var feedContext = new FeedContext(id, localize("Ramping"), feedPerRev ? getParameter("operation:tool_feedRampRel") : getParameter("operation:tool_feedRamp"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_RAMP] = feedContext;
      activeMovements[MOVEMENT_RAMP_HELIX] = feedContext;
      activeMovements[MOVEMENT_RAMP_PROFILE] = feedContext;
      activeMovements[MOVEMENT_RAMP_ZIG_ZAG] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedPlunge")) {
    if (movements & (1 << MOVEMENT_PLUNGE)) {
      var feedContext = new FeedContext(id, localize("Plunge"), feedPerRev ? getParameter("operation:tool_feedPlungeRel") : getParameter("operation:tool_feedPlunge"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_PLUNGE] = feedContext;
    }
    ++id;
  }
  if (true) { // high feed
    if ((movements & (1 << MOVEMENT_HIGH_FEED)) || (highFeedMapping != HIGH_FEED_NO_MAPPING)) {
      var feed;
      if (hasParameter("operation:highFeedrateMode") && getParameter("operation:highFeedrateMode") != "disabled") {
        feed = getParameter("operation:highFeedrate");
      } else {
        feed = this.highFeedrate;
      }
      var feedContext = new FeedContext(id, localize("High Feed"), feed);
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_HIGH_FEED] = feedContext;
      activeMovements[MOVEMENT_RAPID] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedTransition")) {
    if (movements & (1 << MOVEMENT_LINK_TRANSITION)) {
      var feedContext = new FeedContext(id, localize("Transition"), getParameter("operation:tool_feedTransition"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_TRANSITION] = feedContext;
    }
    ++id;
  }

  for (var i = 0; i < activeFeeds.length; ++i) {
    var feedContext = activeFeeds[i];
    writeBlock("#" + (firstFeedParameter + feedContext.id) + "=" + feedFormat.format(feedContext.feed), formatComment(feedContext.description));
  }
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function cancelWorkPlane() {
  cancelTransformation();
  if (gotBAxis && (activeTurret != 2)) {
    if (bAxisIsManual) {
      writeBlock(gWCSModal.format(69.1));
    } else {
      writeBlock(gWCSModal.format(369));
    }
    forceWorkPlane();
  }
}

function getTCP(abc) {
  tcp = (gotBAxis && activeTurret != 2) &&
    (machineState.axialCenterDrilling ||
      // (getProperty("useG400") && (Math.abs(bFormat.getResultingValue(abc.y)) == 90)) ||
      (machineState.usePolarInterpolation || machineState.usePolarCoordinates));
  return tcp;
}

// determines if G368 is used
function useG368(abc) {
  if ((gotBAxis && (activeTurret != 2)) && (abc.y != 0) && !bAxisIsManual) {
    // if (!(getProperty("useG400") && ((bFormat.getResultingValue(abc.y) == 0) || (Math.abs(bFormat.getResultingValue(abc.y)) == 90)))) {
    //   return true;
    // }
  }
  return false;
}

function setWorkPlane(abc) {
  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }

  if (!((currentWorkPlaneABC == undefined) ||
    abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
    abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
    abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z))) {
    return; // no change
  }

  //onCommand(COMMAND_UNLOCK_MULTI_AXIS);

  if ((gotBAxis && (activeTurret != 2)) && (abc.y != 0)) {
    if (bAxisIsManual) {
      writeBlock(
        gMotionModal.format(0),
        conditional(machineConfiguration.isMachineCoordinate(0), aOutput.format(abc.x)),
        conditional(machineConfiguration.isMachineCoordinate(1), bFormat.format(abc.y)),
        conditional(machineConfiguration.isMachineCoordinate(2), cOutput.format(abc.z))
      );
      if (useMultiAxisFeatures) {
        writeBlock(gWCSModal.format(68.1),
          "X" + spatialFormat.format(0),
          conditional(gotYAxis, "Y" + spatialFormat.format(0)),
          "Z" + spatialFormat.format(0),
          "I" + spatialFormat.format(0),
          "J" + spatialFormat.format(1),
          "K" + spatialFormat.format(0),
          "R" + abcFormat.format((getSpindle(PART) == SPINDLE_MAIN) ? abc.y : -abc.y)
        );
      }
    } else {
      if (((bFormat.getResultingValue(abc.y) == 0) || (Math.abs(bFormat.getResultingValue(abc.y)) == 90))) {
        if (currentWorkPlaneABC == undefined || abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y)) {
          setSpindleOrientationMilling(abc);
        }
      } else if (currentWorkPlaneABC == undefined || abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) || gWCSModal.getCurrent() == 369) {
        var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
        var toolAxisMode = (machineState.usePolarInterpolation || machineState.usePolarCoordinates || machineState.axialCenterDrilling) ? 0 : 1;  // D0 = tool axis is Z-axis, D1 = tool axis is X-axis
        gWCSModal.reset();
        writeBlock(
          gWCSModal.format(368),
          "X" + spatialFormat.format(0),
          "Z" + spatialFormat.format(0),
          "D" + spatialFormat.format(toolAxisMode),
          bFormat.format((getSpindle(PART) == SPINDLE_MAIN) ? abc.y : -abc.y), // only B-axis is supported for G368
          "W" + compensationOffset
        );
      }
      if ((getSpindle(TOOL) == SPINDLE_LIVE) && machineConfiguration.isMachineCoordinate(2)) {
        writeBlock(gMotionModal.format(0), cOutput.format(abc.z));
      }
    }
  } else {
    /*if (getProperty("useG400") && (activeTurret != 2)) {
      setSpindleOrientationMilling(abc);
      if ((getSpindle(TOOL) == SPINDLE_LIVE) && machineConfiguration.isMachineCoordinate(2)) {
        writeBlock(gMotionModal.format(0), cOutput.format(abc.z));
      }
    } else {*/
    writeBlock(
      gMotionModal.format(0),
      conditional(machineConfiguration.isMachineCoordinate(0), aOutput.format(abc.x)),
      conditional(machineConfiguration.isMachineCoordinate(1), bFormat.format(abc.y)),
      conditional(machineConfiguration.isMachineCoordinate(2), cOutput.format(abc.z))
    );
    //}
  }

  if (!machineState.usePolarInterpolation && !machineState.usePolarCoordinates && !currentSection.isMultiAxis() &&
    (getSpindle(TOOL) == SPINDLE_LIVE)) {
    //  onCommand(COMMAND_LOCK_MULTI_AXIS);
  }

  currentWorkPlaneABC = new Vector(abc);
  setCurrentDirection(abc);
}

function getBestABC(section) {
  // try workplane orientation
  var abc = section.getABCByPreference(machineConfiguration, section.workPlane, getCurrentDirection(), C, PREFER_CLOSEST, ENABLE_ALL);
  if (section.doesToolpathFitWithinLimits(machineConfiguration, abc)) {
    return abc;
  }
  var currentABC = new Vector(abc);

  // quadrant boundaries are the preferred solution
  var quadrants = [0, 90, 180, 270];
  for (var i = 0; i < quadrants.length; ++i) {
    abc.setZ(toRad(quadrants[i]));
    if (section.doesToolpathFitWithinLimits(machineConfiguration, abc)) {
      abc = machineConfiguration.remapToABC(abc, currentABC);
      abc = machineConfiguration.remapABC(abc);
      return abc;
    }
  }

  // attempt to find soultion at fixed angle rotations
  var maxTries = 60; // every 6 degrees
  var delta = (Math.PI * 2) / maxTries;
  var angle = delta;
  for (var i = 0; i < (maxTries - 1); i++) {
    abc.setZ(angle);
    if (section.doesToolpathFitWithinLimits(machineConfiguration, abc)) {
      abc = machineConfiguration.remapToABC(abc, currentABC);
      abc = machineConfiguration.remapABC(abc);
      return abc;
    }
    angle += delta;
  }
  return abc;
}

function getWorkPlaneMachineABC(section, workPlane) {
  var W = workPlane; // map to global frame

  var abc;
  if (machineState.isTurningOperation && gotBAxis) {
    var both = machineConfiguration.getABCByDirectionBoth(workPlane.forward);
    abc = both[0];
    if (both[0].z != 0) {
      abc = both[1];
    }
  } else {
    abc = bestABC ? bestABC :
      section.getABCByPreference(machineConfiguration, W, getCurrentDirection(), C, PREFER_CLOSEST, ENABLE_RESET);
  }

  var direction = machineConfiguration.getDirection(abc);
  if (!isSameDirection(direction, W.forward)) {
    error(localize("Orientation not supported."));
  }

  if (machineState.isTurningOperation && gotBAxis && !bAxisIsManual) { // remapABC can change the B-axis orientation
    if (abc.z != 0) {
      error(localize("Could not calculate a B-axis turning angle within the range of the machine."));
    }
  }

  var tcp = getTCP(abc);
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    if (true) {
      var tempABC = (/*getProperty("useG400") &&*/ (Math.abs(bFormat.getResultingValue(abc.y)) == 90)) ?
        new Vector(abc.x, 0, abc.z) : new Vector(abc.x, (useMultiAxisFeatures ? abc.y : 0), abc.z);
      // Use for a Z-axis orientation rather than an X-axis orientation with a B-axis
      // Other changes are required when not using G368 for this operation
      // Need to support sub-spindle
      /*if (gotBAxis && isSameDirection(machineConfiguration.getSpindleAxis().abs, new Vector(1, 0, 0))) {
        tempABC = new Vector(abc.x, toRad(90) + abc.y, abc.z);
      }*/
      var O = machineConfiguration.getOrientation(tempABC);
      var R = machineConfiguration.getRemainingOrientation(tempABC, W);
      setRotation(R);
    }
  }

  if (machineState.usePolarCoordinates) { // set C-axis to initial polar coordinate position
    var initialPosition = getFramePosition(section.getInitialPosition());
    var polarPosition = getPolarCoordinates(initialPosition, abc);
    abc.setZ(polarPosition.second.z);
  }
  return abc;
}

var bAxisOrientationTurning = new Vector(0, 0, 0);

function setSpindleOrientationTurning(insertToolCall) {
  cancelTransformation();
  var leftHandtool;
  if (hasParameter("operation:tool_hand")) {
    if (getParameter("operation:tool_hand") == "L") { // TAG: add neutral tool to Left hand case
      if (getParameter("operation:tool_holderType") == 0) {
        leftHandtool = false;
      } else {
        leftHandtool = true;
      }
    } else {
      leftHandtool = false;
    }
  }
  var J;
  var R;
  var spindleMain = getSpindle(PART) == SPINDLE_MAIN;

  if (hasParameter("operation:turningMode") && (getParameter("operation:turningMode") == "front")) {
    if ((getParameter("operation:direction") == "front to back")) {
      R = spindleMain ? 2 : 1;
    } else {
      R = spindleMain ? 3 : 4;
    }
  } else if (hasParameter("operation:machineInside")) {
    if (getParameter("operation:machineInside") == 0) {
      R = spindleMain ? 3 : 4;
    } else {
      R = spindleMain ? 2 : 1;
    }
  } else {
    if ((hasParameter("operation-strategy") && (getParameter("operation-strategy") == "turningFace") ||
      (hasParameter("operation-strategy") && (getParameter("operation-strategy") == "turningPart")))) {
      R = spindleMain ? 3 : 4;
    } else {
      error(localize("Failed to identify R-value for G400 for Operation " + "\"" + (getParameter("operation-comment").toUpperCase()) + "\""));
      return;
    }
  }
  if (leftHandtool) {
    J = spindleMain ? 2 : 1;
  } else {
    J = spindleMain ? 1 : 2;
  }
  if ((bAxisOrientationTurning.y < machineConfiguration.getAxisU().getRange().getMinimum()) ||
    (bAxisOrientationTurning.y > machineConfiguration.getAxisU().getRange().getMaximum())) {
    error(localize("B-Axis Orientation is out of range in operation " + "\"" + (getParameter("operation-comment").toUpperCase()) + "\""));
  }

  if (insertToolCall || abcFormat.areDifferent(machineState.currentBAxisOrientationTurning.y, bAxisOrientationTurning.y) || (previousSpindle != getSpindle(PART))) {
    if (!spindleMain) {
      bAxisOrientationTurning.y *= -1;
    }
    if (!insertToolCall) {
      goHome();
      writeBlock("T" + toolFormat.format(currentToolCode));
    }
    writeBlock(gFormat.format(400), "B" + spatialFormat.format(toDeg(bAxisOrientationTurning.y)), "J" + spatialFormat.format(J), "R" + spatialFormat.format(R));
  }
  machineState.currentBAxisOrientationTurning.y = bAxisOrientationTurning.y;
}

function getBAxisOrientationTurning(section) {
  var toolAngle = hasParameter("operation:tool_angle") ? getParameter("operation:tool_angle") : 0;
  var toolOrientation = section.toolOrientation;
  if (toolAngle && toolOrientation != 0) {
    // error(localize("You cannot use tool angle and tool orientation together in operation " + "\"" + (getParameter("operation-comment")) + "\""));
  }

  var angle = toRad(toolAngle) + toolOrientation;

  var axis = new Vector(0, 1, 0);
  var mappedAngle;
  if (bAxisIsManual) {
    mappedAngle = 0; // manual b-axis used for milling only
  } else {
    mappedAngle = (currentSection.spindle == SPINDLE_PRIMARY ? (Math.PI / 2 - angle) : (Math.PI / 2 - angle));
  }
  var mappedWorkplane = new Matrix(axis, mappedAngle);
  var abc = getWorkPlaneMachineABC(section, mappedWorkplane);
  return abc;
}

function setSpindleOrientationMilling(abc) {
  /*if (getProperty("useG400")) {
    var J;
    switch (getSpindle(TOOL)) {
    case SPINDLE_MAIN:
      J = 1;
      break;
    case SPINDLE_SUB:
      J = 2;
      break;
    case SPINDLE_LIVE:
      J = 0;
      break;
    }
    bOutput.reset();
    writeBlock(gFormat.format(400), bOutput.format(getB(abc, currentSection)), "J" + spatialFormat.format(J));
    writeBlock(mFormat.format(101)); // unclamp B-axis after G400 - per manual
  } else {*/
  if (gWCSModal.getCurrent() != 369 && !bAxisIsManual) {
    writeBlock(gFormat.format(369));
  }
  bOutput.reset();
  writeBlock(gMotionModal.format(0), bOutput.format(getB(abc, currentSection)));
  //}
}

function getSpindle(whichSpindle) {
  // safety conditions
  if (getNumberOfSections() == 0) {
    return SPINDLE_MAIN;
  }
  if (getCurrentSectionId() < 0) {
    if (machineState.liveToolIsActive && (whichSpindle == TOOL)) {
      return SPINDLE_LIVE;
    } else {
      return getSection(getNumberOfSections() - 1).spindle;
    }
  }

  // Turning is active or calling routine requested which spindle part is loaded into
  if (machineState.isTurningOperation || machineState.axialCenterDrilling || (whichSpindle == PART)) {
    return currentSection.spindle;
    //Milling is active
  } else {
    return SPINDLE_LIVE;
  }
}

function getSecondarySpindle() {
  var spindle = getSpindle(PART);
  return (spindle == SPINDLE_MAIN) ? SPINDLE_SUB : SPINDLE_MAIN;
}

/** Calculate the C-axis scale value */ // TAG Polar interpolation does not support a 0,0,-1 axis vector
function getCScale(scale) {
  if (machineState.usePolarCoordinates) {
    if (Vector.dot(machineConfiguration.getAxisU().getAxis(), new Vector(0, 0, 1)) != 0) {
      direction = (machineConfiguration.getAxisU().getAxis().getCoordinate(2) >= 0) ? 1 : -1; // C-axis is the U-axis
    } else {
      direction = (machineConfiguration.getAxisV().getAxis().getCoordinate(2) >= 0) ? 1 : -1; // C-axis is the V-axis
    }
    return scale * direction;
  } else {
    return scale;
  }
}

/** Invert YZC axes for the sub-spindle. */
function invertAxes(activate, polarMode) {
  var scaleValue = reverseAxes ? (polarMode ? 1 : -1) : 1;
  var yAxisPrefix = polarMode ? "C" : "Y";
  var yIsEnabled = yOutput.isEnabled();
  yFormat.setScale(activate ? scaleValue : 1);
  zFormat.setScale(activate ? -1 : 1);
  cFormat.setScale(DEG * (activate ? getCScale(scaleValue) : getCScale(1)));

  yOutput.setFormat(yFormat);
  yOutput.setPrefix(yAxisPrefix);
  zOutput.setFormat(zFormat);
  cOutput.setFormat(cFormat);
  if (polarMode) {
    cOutput.disable();
  } else {
    if (!yIsEnabled) {
      yOutput.disable();
    }
  }
  jOutput.setFormat(yFormat);
  kOutput.setFormat(zFormat);
}

/** determines if the axes in the given plane are mirrored */
function isMirrored(plane) {
  plane = plane == -1 ? getCompensationPlane(getCurrentDirection(), false, false) : plane;
  switch (plane) {
  case PLANE_XY:
    if ((xFormat.getScale() * yFormat.getScale()) < 0) {
      return true;
    }
    break;
  case PLANE_YZ:
    if ((yFormat.getScale() * zFormat.getScale()) < 0) {
      return true;
    }
    break;
  case PLANE_ZX:
    if ((zFormat.getScale() * xFormat.getScale()) < 0) {
      return true;
    }
    break;
  }
  return false;
}

function isPerpto(a, b) {
  return Math.abs(Vector.dot(a, b)) < (1e-7);
}

function onSectionSpecialCycle() {
  if (!isFirstSection()) {
    activateMachine(currentSection);
  }
}

function debugSectionHeader(str) {
  if (debugMode) {
    writeln("\n");
    writeln("-----" + str + "-----");
  }
}

let shouldRedirect = true;
let redirectStarted = false;
let groupedOperations = false;
const GroupedbAxis = false;

function b64Output() {
  // if (!debugMode){
  if (!sectionObject.ncLocation) {
    return;
  }
  let file = new TextFile(sectionObject.ncLocation, false, "ansi");
  // }
  let contents = "";
  try {
    while (true) {
      contents += file.readln() + "\n";
    }
  } catch (error) {
    file.close();
  }
  if (file.isOpen()) {
    file.close();
  }
  //let file = new TextFile(sectionObject.ncLocation, true, 'ansi');
  file = new TextFile(sectionObject.ncLocation, true, "ansi");
  file.write(Base64.btoa(contents));
  file.close();

}
function writeDebug(_text) {
  writeComment("DEBUG - " + _text);
}

function formatComment(text) {
  return "(" + String(filterText(String(text).toUpperCase(), permittedCommentChars)).replace(/[()]/g, "") + ")";
}

function formatText(text) {
  return String(filterText(String(text).toUpperCase(), permittedCommentChars)).replace(/[()]/g, "");
}

function closeSection() {
  debugSectionHeader("closeSection");
  if (groupedOperations && !closedSection) {
    closedSection = true;
    gMotionModal.reset();
    gPlaneModal.reset();
    gFeedModeModal.reset();
    gSpindleModeModal.reset();
    gSpindleModal.reset();
    gUnitModal.reset();
    gCycleModal.reset();
    gPolarModal.reset();
    cAxisBrakeModal.reset();
    mInterferModal.reset();
    cAxisEngageModal.reset();
    gWCSModal.reset();
    tailStockModal.reset();
    xOutput.reset();
    yOutput.reset();
    zOutput.reset();
    aOutput.reset();
    bOutput.reset();
    cOutput.reset();
    barOutput.reset();
    feedOutput.reset();
    pitchOutput.reset();
    threadP1Output.reset();
    threadP2Output.reset();
    threadQOutput.reset();
    threadROutput.reset();
    var liveTool = getSpindle(TOOL) == SPINDLE_LIVE;
    optionalSection = false;
    // onCommand(COMMAND_STOP_SPINDLE);
    setCoolant(COOLANT_OFF);
    writeln("");
    // if (getProperty("gotChipConveyor")) {
    //  onCommand(COMMAND_STOP_CHIP_TRANSPORT);
    // }
    // Move to home position
    //goHome();
    if (machineState.tailstockIsActive) {
      //  engageTailStock(false);
    }

    cancelWorkPlane();

    // if (!getProperty("optimizeCAxisSelect")) {
    //  cAxisEngageModal.reset();
    // }
    if (liveTool) {
      // writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", getSpindle(PART))));
      //   onCommand(COMMAND_UNLOCK_MULTI_AXIS);
      //   unwindCAxis();
      //   onCommand(COMMAND_LOCK_MULTI_AXIS);
    }
    //writeBlock(cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSpindle(PART))));

    // Automatically eject part
    if (ejectRoutine) {
      //  ejectPart();
    }

    //  writeBlock(gFormat.format(54));

    // Process Manual NC commands
    executeManualNC();

    writeln("");
    //onImpliedCommand(COMMAND_END);
    if (gotSecondarySpindle) {
      //writeBlock(mInterferModal.format(getCode("INTERFERENCE_CHECK_ON", getSpindle(PART))));
    }
    /* if (getProperty("looping")) {
       writeBlock(mFormat.format(54), formatComment(localize("Increment part counter"))); //increment part counter
       writeBlock(mFormat.format(99));
     } else {*/
    //  onCommand(COMMAND_OPEN_DOOR);
    //  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
    //}
    //writeln("%");
    if (machineState.usePolarMode) {
      setPolarMode(false); // disable polar interpolation mode
      writeBlock(gPlaneModal.format(17));
    }

    // cancel SFM mode to preserve spindle speed
    if ((tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
      writeBlock(gFormat.format(97));
    }

    forceXZCMode = false;
    forcePolarMode = false;
    partCutoff = false;
    tooloffsetOutput = false;
    onCommand(COMMAND_STOP_SPINDLE);

    forceAny();
    shouldRedirect = false;
    if (properties.miyano_subroutineAll) {
      writeBlock(mFormat.format(99));
    }
  }
}

function onSection() {
  debugSectionHeader("onSection");

  // used to output the section
  debugSectionHeader("redirectSection");

  shouldRedirect = !groupedOperations || isFirstSection() || tool.number != getPreviousSection().getTool().number;

  if (shouldRedirect || !redirectStarted) {

    if (!debugMode && isRedirecting()) {
      closeSection();
      closeRedirection();
      b64Output();
    }
    redirectSection();
  }

  offsetFactor = getToolOffsetFactor(tool);
  toolFormat.setMinDigitsLeft(offsetFactor == 1000 ? 5 : 4);

  // Detect machine configuration
  var currentTurret = isFirstSection() ? activeTurret : activateMachine(currentSection);

  // Define Machining modes
  tapping = isTappingCycle();

  var forceSectionRestart = optionalSection && !currentSection.isOptional();
  optionalSection = currentSection.isOptional();
  bestABC = undefined;
  setCurrentDirection(isFirstSection() ? new Vector(0, 0, 0) : getCurrentDirection());

  machineState.isTurningOperation = (currentSection.getType() == TYPE_TURNING);
  if (machineState.isTurningOperation && gotBAxis) {
    bAxisOrientationTurning = getBAxisOrientationTurning(currentSection);
  }
  //check tool nubers and alarm if not in range
  if (tool.number >= 72) {
    error(localize("Tool " + tool.number + " is not available.  Please select a tool number between 1 and 12."));
  }

  var insertToolCall = isToolChangeNeeded("number", "compensationOffset", "diameterOffset", "lengthOffset") || forceSectionRestart;
  var newWorkOffset = isNewWorkOffset() || forceSectionRestart;
  var newWorkPlane = isNewWorkPlane() || forceSectionRestart ||
    (machineState.isTurningOperation &&
      abcFormat.areDifferent(bAxisOrientationTurning.x, machineState.currentBAxisOrientationTurning.x) ||
      abcFormat.areDifferent(bAxisOrientationTurning.y, machineState.currentBAxisOrientationTurning.y) ||
      abcFormat.areDifferent(bAxisOrientationTurning.z, machineState.currentBAxisOrientationTurning.z));
  var retracted = false; // specifies that the tool has been retracted to the safe plane

  partCutoff = getParameter("operation-strategy", "") == "turningPart";

  var yAxisWasEnabled = !machineState.usePolarCoordinates && !machineState.usePolarInterpolation && machineState.liveToolIsActive;
  updateMachiningMode(currentSection); // sets the needed machining mode to machineState (usePolarInterpolation, usePolarCoordinates, axialCenterDrilling)

  // force tool change on G368 change
  if (!insertToolCall && !machineState.isTurningOperation && gotBAxis && (currentTurret != 2) && !bAxisIsManual && !currentSection.isMultiAxis()) {
    var previous = getCurrentDirection();
    var abc = getWorkPlaneMachineABC(currentSection, currentSection.workPlane);
    insertToolCall = useG368(abc) && ((currentWorkPlaneABC == undefined) ||
      abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y));
    setCurrentDirection(previous);
  }

  // Get the active spindle
  var newSpindle = true;
  var tempSpindle = getSpindle(TOOL);
  var forceSpindle = false;
  if (isFirstSection()) {
    previousSpindle = tempSpindle;
  }
  newSpindle = tempSpindle != previousSpindle;

  headOffset = tool.getBodyLength();
  // End the previous section if a new tool is selected
  if (!isFirstSection() && insertToolCall) {
    if (machineState.spindlesAreSynchronized || machineState.cAxesAreSynchronized) {
      if (!machineState.spindlesAreAttached) {
        onCommand(COMMAND_STOP_SPINDLE);
      }
    } else {
      if (previousSpindle == SPINDLE_LIVE) {
        //onCommand(COMMAND_STOP_SPINDLE)
        forceUnlockMultiAxis();
        //   onCommand(COMMAND_UNLOCK_MULTI_AXIS);
        //if ((tempSpindle != SPINDLE_LIVE) && !getProperty("optimizeCAxisSelect")) {
        //  cAxisEngageModal.reset();
        // writeBlock(cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSpindle(PART))));
        // if (machineState.spindlesAreAttached) {
        //   writeBlock(cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSecondarySpindle())));
        // }
      }
      //} else {
      if (tool.clockwise != getPreviousSection().getTool().clockwise) {
        //if (forceTurningMode) {
        //  cAxisEngageModal.reset();
        //writeBlock(cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSpindle(PART))));
        // if (machineState.spindlesAreAttached) {
        //  writeBlock(cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSecondarySpindle())));
        // }
        //}
        onCommand(COMMAND_STOP_SPINDLE);
      }
      //}
    }
    forceTurningMode = false;
    // onCommand(COMMAND_COOLANT_OFF);
    // goHome();
    mInterferModal.reset();
    if (gotSecondarySpindle) {
      //  writeBlock(mInterferModal.format(getCode("INTERFERENCE_CHECK_OFF", getSpindle(PART))));
    }

  }

  // Consider part cutoff as stockTransfer operation
  if (!(machineState.stockTransferIsActive && partCutoff)) {
    machineState.stockTransferIsActive = false;
  }

  // cancel previous work plane
  if (insertToolCall) { // insertToolCall is enabled when a B-axis change results in a G368 block
    cancelWorkPlane();
  }

  // Process Pass Through commands
  executeManualNC();

  // Output the operation description
  writeln("");
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      if (insertToolCall && properties.miyano_sequenceNumbers == "toolChange") {
        writeCommentSeqno(comment);
      } else {
        writeComment(comment);
      }
    }
  }
  //Add startup line for all toolpaths - BNE
  //G18G40G80G97G99 turning
  //G18G40G80G97G98 milling
  if (shouldRedirect || !redirectStarted) {
    debugSectionHeader("safeStartSection");
    safeStartSection(tempSpindle, newSpindle, abc);
    closedSection = false;
  }
  gPlaneModal.reset();
  
  
  
  goHome();
  writeBlock(gPlaneModal.format(18), gFormat.format(40), gFormat.format(80), gFormat.format(getCode("CONSTANT_SURFACE_SPEED_OFF")), (currentSection.feedMode == FEED_PER_REVOLUTION ? gFormat.format(getCode("FEED_MODE_UNIT_REV")) : gFormat.format(getCode("FEED_MODE_UNIT_MIN"))));
  // invert axes for turret 2
 turretNum = currentSection.getTool().turret;
  invertAxes(currentTurret == 1, false); // polar mode has not been enabled yet
  //Apply 180 degree offset if lower turret is used
  if (turretNum == 1) {
    cOutput.setOffset(180);
    if (getSection(0).spindle == SPINDLE_PRIMARY) {
      zOutput.setScale(1);
      yOutput.setScale(-1);
    } else {
      yOutput.setScale(1);
    }
  }
  if (turretNum == 1 || turretNum == 2) {
    if (getSection(0).spindle == SPINDLE_SECONDARY) {
      zOutput.setScale(-1);
      yOutput.setScale(-1);
    }
  }
  // Position all axes at home
  if (insertToolCall && !machineState.stockTransferIsActive) {
    // goHome(); - removed - BNE

    // Stop the spindle

  }

  // wcs - output work offset for every operation
  if (insertToolCall) { // force work offset when changing tool
    currentWorkOffset = undefined;
  }

  var wcsOut = "";
  // Output work offset for every operation (removed conditional check)
  forceWorkPlane();
 
  wcsOut = currentSection.wcs;
  currentWorkOffset = currentSection.workOffset;
  if (turretNum == 2) {
    if (currentSection.spindle == SPINDLE_MAIN) {
      wcsOut = gFormat.format(54);
    } else {
      error(localize("Turret 1 is only available for the main spindle."));
    }
  } else if (turretNum == 1) {
    if (currentSection.spindle == SPINDLE_MAIN) {
      wcsOut = gFormat.format(54);
    } else {
      wcsOut = gFormat.format(55);
    }
  } else {
    //error(localize("Invalid turret number for work offset."));
    turretNum = 1;
    if (currentSection.spindle == SPINDLE_MAIN) {
      wcsOut = gFormat.format(54);
    } else {
      error(localize("Turret Defaulted to 1 but is only available for the main spindle."));
    }
  }
  writeBlock(wcsOut);

  // Get active feedrate mode
  if (insertToolCall) {
    forceModals();
  }
  var feedMode = formatFeedMode(currentSection.feedMode);

  // calculate rotary angles
  var abc = new Vector(0, 0, 0);
  if (machineConfiguration.isMultiAxisConfiguration()) {
    if (machineState.isTurningOperation) {
      if (gotBAxis && (currentTurret != 2)) {
        cancelTransformation();
        // handle B-axis support for turning operations here
        abc = bAxisOrientationTurning;
      } else {
        abc = getWorkPlaneMachineABC(currentSection, currentSection.workPlane);
      }
    } else {
      if (currentSection.isMultiAxis() || isPolarModeActive()) {
        forceWorkPlane();
        cancelTransformation();
        abc = currentSection.isMultiAxis() ? currentSection.getInitialToolAxisABC() : getCurrentDirection();
      } else {
        abc = getWorkPlaneMachineABC(currentSection, currentSection.workPlane);
      }
    }
  } else { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported by the CNC machine."));
      return;
    }
    setRotation(remaining);
  }

  // Live Spindle is active
  if (tempSpindle == SPINDLE_LIVE) {
    if (insertToolCall || wcsOut || feedMode) {
      // get machining plane
      var plane;
      var found = false;
      if ((gotBAxis && (currentTurret != 2)) && !bAxisIsManual) {
        if (useG368(abc) && !machineState.usePolarInterpolation && !machineState.usePolarCoordinates) {
          plane = 19; // use G19 for B-axis with 368 mode
          localZoutput = xOutput;
          found = true;
        }
      }
      if (!found) {
        plane = machineState.machiningDirection == MACHINING_DIRECTION_AXIAL ? getG17Code() : 18;
      }
      gPlaneModal.reset();

      /* if (!getProperty("optimizeCAxisSelect")) {
         cAxisEngageModal.reset();
         forceUnlockMultiAxis();
       }*/
      //writeBlock(wcsOut);
      if (!machineState.spindlesAreAttached) {
        // writeBlock(feedMode, gPlaneModal.format(plane), cAxisEngageModal.format(getCode("ENABLE_C_AXIS", getSpindle(PART))));
        //onCommand(COMMAND_UNLOCK_MULTI_AXIS);
        //unwindCAxis();
        if (!machineState.usePolarInterpolation && !machineState.usePolarCoordinates && !currentSection.isMultiAxis()) {
          // onCommand(COMMAND_LOCK_MULTI_AXIS);
        }
      } else {
        writeBlock(feedMode, gPlaneModal.format(plane));
      }
    } else {
      if (machineState.usePolarInterpolation || machineState.usePolarCoordinates || currentSection.isMultiAxis()) {
        onCommand(COMMAND_UNLOCK_MULTI_AXIS);
      }
    }

    // Turning is active
  } else {
    /*  if ((insertToolCall || wcsOut || feedMode) && !machineState.stockTransferIsActive) {
        if (!useCAxisSelectWithTurning) {
          cAxisEngageModal.format(getCode("ENABLE_C_AXIS", getSpindle(PART)));
        } else if (!getProperty("optimizeCAxisSelect")) {
          cAxisEngageModal.reset();
        }
        if (insertToolCall) {
          forceUnlockMultiAxis();
          gPlaneModal.reset();
        }
        onCommand(COMMAND_UNLOCK_MULTI_AXIS);
        writeBlock(wcsOut);
        writeBlock(feedMode, gPlaneModal.format(18),
          conditional(useCAxisSelectWithTurning), cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSpindle(PART))));
      } else {
        if (wcsOut) {
          writeBlock(wcsOut);
        }
        writeBlock(feedMode);
      }*/ //- All of this not required for BNE - left in in case we need to add anything in at a later date
  }

  //if (!tapping) {
    forceRPMMode = (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) && !machineState.spindlesAreAttached && !machineState.spindlesAreSynchronized;
    startSpindle(false, forceRPMMode, getFramePosition(currentSection.getInitialPosition()), true);
  //}
  if ((getSpindle(PART) == SPINDLE_MAIN)) {
    writeBlock(mFormat.format(91)); // Main spindle
  } else {
    writeBlock(mFormat.format(191)); // Sub spindle
  }
  // Write out notes
  /*if (getProperty("showNotes") && hasParameter("notes")) {
    var notes = getParameter("notes");
    if (notes) {
      var lines = String(notes).split("\n");
      var r1 = new RegExp("^[\\s]+", "g");
      var r2 = new RegExp("[\\s]+$", "g");
      for (line in lines) {
        var comment = lines[line].replace(r1, "").replace(r2, "");
        if (comment) {
          writeComment(comment);
        }
      }
    }
  }*/

  switch (machineState.machiningDirection) {
  case MACHINING_DIRECTION_AXIAL:
    // writeBlock(gPlaneModal.format(getG17Code()));
    break;
  case MACHINING_DIRECTION_RADIAL:
    if (gotBAxis && (currentTurret != 2)) {
      // writeBlock(gPlaneModal.format(getG17Code()));
    } else {
      // writeBlock(gPlaneModal.format(getG17Code())); // RADIAL
    }
    break;
  case MACHINING_DIRECTION_INDEXING:
    // writeBlock(gPlaneModal.format(getG17Code())); // INDEXING
    break;
  default:
    error(subst(localize("Unsupported machining direction for operation " + "\"" + "%1" + "\"" + "."), getOperationComment()));
    return;
  }

  if (currentSection.isMultiAxis()) {
    onCommand(COMMAND_UNLOCK_MULTI_AXIS);
  }

  if (insertToolCall) {
    forceWorkPlane();
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);

    var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;

    if (compensationOffset > (useExtendedOffsets ? 999 : 99)) {
      error(localize("Compensation offset is out of range."));
      return;
    }

    if (tool.number > 72) {
      warning(localize("Tool number exceeds maximum value."));
    }

    if (tool.number == 0) {
      error(localize("Tool number cannot be 0"));
      return;
    }

    gMotionModal.reset();

    // preselect first tool or when turret changes back to 1
    if ((isFirstSection() || (currentTurret == 1 && activeTurret == 2)) && (currentTurret != 2)) {
      //  writeBlock("T" + toolFormat.format(tool.number * offsetFactor));
    }

    if (currentTurret != 2) {
      // writeBlock(mFormat.format(6), "T" + toolFormat.format(tool.number * offsetFactor));
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        if (nextTool.turret != 2) {
          //   writeBlock("T" + toolFormat.format(nextTool.number * offsetFactor), formatComment("NEXT TOOL"));
        }
      } else {
        // preload first tool
        var section = getSection(0);
        var firstToolNumber = section.getTool().number;
        if ((tool.number != firstToolNumber) && (section.getTool().turret != 2)) {
          //    writeBlock("T" + toolFormat.format(firstToolNumber * offsetFactor), formatComment("NEXT TOOL"));
        }
      }
    }
    currentToolCode = tool.number * offsetFactor + compensationOffset;
    //  writeBlock("T" + toolFormat.format(currentToolCode));
    if (tool.comment) {
      //   writeComment(tool.comment);
    }
    activeTurret = currentTurret;
  }

  // Turn on coolant
  //setCoolant(tool.coolant);

  // Activate part catcher for part cutoff section
  //if (getProperty("usePartCatcher") && partCutoff && currentSection.partCatcher) {
  //  engagePartCatcher(true);
  //}

  // command stop for manual tool change, useful for quick change live tools
  if (insertToolCall && tool.manualToolChange) {
    onCommand(COMMAND_STOP);
    writeBlock("(" + "MANUAL TOOL CHANGE TO T" + toolFormat.format(currentToolCode) + ")");
  }

  // Engage tailstock
  //if (getProperty("useTailStock") != "false") {
  //   if (!retracted && ((currentSection.tailstock || forceTailStock) != machineState.tailstockIsActive)) {
  //     goHome();
  //     retracted = true;
  //   }
  //   engageTailStock(true);
  // }

  // Check operation type with connected spindles
  if (machineState.spindlesAreAttached) {
    if (machineState.axialCenterDrilling || (getSpindle(PART) == SPINDLE_SUB) ||
      (getParameter("operation-strategy") == "turningFace") ||
      ((getSpindle(TOOL) == SPINDLE_LIVE) && (machineState.machiningDirection == MACHINING_DIRECTION_AXIAL))) {
      error(localize("Illegal cutting operation programmed when spindles are synchronized."));
      return;
    }
  }

  // Output spindle codes
  if (newSpindle) {
    // select spindle if required
  }

  var forceRPMMode = false;
  var spindleChanged = tool.type != TOOL_PROBE && (!machineState.stockTransferIsActive || forceSpindle) &&
    (insertToolCall || forceSpindleSpeed || isSpindleSpeedDifferent() || newSpindle);
  if (spindleChanged) {
    forceSpindleSpeed = false;
    if (machineState.isTurningOperation || machineState.axialCenterDrilling) {
      if (getSpindle(PART) == SPINDLE_MAIN) {
      if (spindleSpeed > properties.miyano_maximumSpindleSpeed) {
        warning(subst(localize("Spindle speed exceeds maximum value for operation \"%1\"."), getOperationComment()));
      }
    } else {
        if (spindleSpeed > properties.miyano_maximumSpindleSpeed2) {
          warning(subst(localize("Spindle speed exceeds maximum value for operation \"%1\"."), getOperationComment()));
        }
      }
    } else {
      if (spindleSpeed > 6000) {
        warning(subst(localize("Spindle speed exceeds maximum value for operation \"%1\"."), getOperationComment()));
      }
    }

    // Turn spindle on
    /* if (!tapping) {
       forceRPMMode = (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) && !machineState.spindlesAreAttached && !machineState.spindlesAreSynchronized;
       startSpindle(false, forceRPMMode, getFramePosition(currentSection.getInitialPosition()));
     }*/
  }
  setCoolant(tool.coolant);
  if (getSection(0).spindle == SPINDLE_PRIMARY && outputCoolant == "M8") {
    writeBlock(mFormat.format(8));
  } else {
    writeBlock(mFormat.format(108));
  }
  if (!machineState.isTurningOperation && !machineState.axialCenterDrilling) {
    writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", getSpindle(PART))));
  }

  // Live Spindle is active with synchronized C-axes
  // need to wait until after spindle speed is output to synchronize the C-axes
  if ((tempSpindle == SPINDLE_LIVE) && machineState.spindlesAreAttached) {
    if (!machineState.cAxesAreSynchronized) {
      writeBlock(mFormat.format(getCode("INTERLOCK_BYPASS", SPINDLE_SUB)), formatComment("INTERLOCK BYPASS"));
      clampChuck(getSecondarySpindle(), UNCLAMP);
      onDwell(1.0);
      writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", SPINDLE_MAIN)));
      writeBlock(cAxisBrakeModal.format(getCode("UNLOCK_MULTI_AXIS", SPINDLE_MAIN)));
      writeBlock(cAxisBrakeModal.format(getCode("UNLOCK_MULTI_AXIS", SPINDLE_SUB)));

      if (transferOrientation == 0) {
        unwindCAxis();
        writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", SPINDLE_SUB)));
        unwindCAxis();
      } else {
        writeBlock(gFormat.format(53), "C" + abcFormat.format(0)); // orientate c-axis
        writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", SPINDLE_SUB)));
        writeBlock(gFormat.format(53), "C" + abcFormat.format(transferOrientation)); // orientate c-axis
      }
      writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", SPINDLE_MAIN)));
      writeBlock(mFormat.format(getCode("CONNECT_C_AXES", SPINDLE_MAIN)), formatComment("SYNCHRONIZE C1 C2"));
      clampChuck(SPINDLE_SUB, CLAMP);
      onDwell(1.0);
    }
  }

  forceAny();
  gMotionModal.reset();

  if (currentSection.isMultiAxis()) {
    if (operationSupportsTCP) {
      writeBlock(mFormat.format(getCode("YAXIS_INTERLOCK_RELEASE_ON")), formatComment("Y-AXIS INTERLOCK RELEASE"));
    } else { // ABC output with prepositioning move
      writeBlock(gMotionModal.format(0), aOutput.format(abc.x), bOutput.format(abc.y), cOutput.format(abc.z));
    }
    forceWorkPlane();
    cancelTransformation();
  } else {
    if (machineState.isTurningOperation && gotBAxis && (activeTurret != 2) && !bAxisIsManual) {
      //  setSpindleOrientationTurning(insertToolCall);
    } else if (machineState.isTurningOperation) {
      if (gotBAxis && (activeTurret != 2)) {
        // setSpindleOrientationMilling(abc);
      }
    } else if ((gotBAxis && (activeTurret != 2)) && !bAxisIsManual) {
      setWorkPlane(abc);
    } else if (!machineState.isTurningOperation && !machineState.axialCenterDrilling && !machineState.usePolarCoordinates && !machineState.usePolarInterpolation) {
      setWorkPlane(abc);
    }
  }
  if (shouldRedirect || !redirectStarted) {
    debugSectionHeader("initialPositioning");
    //initialPositioning(abc);
    redirectStarted = true;
  }
  // enable Polar coordinates mode
  if (machineState.usePolarCoordinates && (tool.type != TOOL_PROBE)) {
    if (polarCoordinatesDirection == undefined) {
      error(localize("Polar coordinates axis direction to maintain must be defined as a vector - x,y,z."));
      return;
    }
    setPolarCoordinates(true);
  }


  forceXYZ();
  gMotionModal.reset();
  var initialPosition = getFramePosition(currentSection.getInitialPosition());

  if (operationSupportsTCP) {
    prepositionXYZ(initialPosition, abc);
    writeBlock("T" + toolFormat.format(tool.number * offsetFactor)); // cancel tool offset compensation
    writeBlock(gFormat.format(700), dFormat.format(tool.lengthOffset), formatComment("ENABLE TCP"));
    writeBlock(mFormat.format(101)); // unclamp B-axis
    forceAny();
  } else if (insertToolCall || retracted || (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
    // gPlaneModal.reset();
    gMotionModal.reset();
    if (machineState.usePolarCoordinates) {
      var polarPosition = getPolarCoordinates(initialPosition, abc);
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      writeBlock(
        gMotionModal.format(0),
        xOutput.format(polarPosition.first.x),
        conditional(gotYAxis, yOutput.format(polarPosition.first.y)),
        cOutput.format(polarPosition.second.z)
      );
    } else if (machineState.usePolarInterpolation) {
      var polarPosition = getPolarCoordinates(initialPosition, abc);
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      writeBlock(
        gMotionModal.format(0),
        xOutput.format(polarPosition.first.x),
        conditional(gotYAxis, yOutput.format(polarPosition.first.y))
      );
    } else if ((gotBAxis && activeTurret != 2) && (abc.y != 0)) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z), yOutput.format(initialPosition.y));
      writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x));
    } else {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), machineState.isTurningOperation ? yOutput.format(0) : yOutput.format(initialPosition.y));
      //writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x));
      //removed Y in turning mode here for Mitsubishi controls - although works, performs a weird move if present
    }
  } else if ((machineState.usePolarCoordinates || machineState.usePolarInterpolation) && yAxisWasEnabled) {
    if (gotYAxis && yOutput.isEnabled()) {
      writeBlock(gMotionModal.format(0), yOutput.format(0));
    }
  }

  // Write out maximum spindle speed
  if (getSpindle(PART) == SPINDLE_MAIN) {
  var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.miyano_maximumSpindleSpeed) : properties.miyano_maximumSpindleSpeed;
  } else {
    var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.miyano_maximumSpindleSpeed2) : properties.miyano_maximumSpindleSpeed2;
  }
  if ((maximumSpindleSpeed > 0) && (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
    //if (insertToolCall) {
    writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
    sOutput.reset();
    previousMaximumSpeed = maximumSpindleSpeed;
    //}
    spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(TOOL)) : getCode("START_SPINDLE_CCW", getSpindle(TOOL)));
    var _spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0);
    writeBlock(gSpindleModeModal.format(getCode("CONSTANT_SURFACE_SPEED_ON")),
      sOutput.format(_spindleSpeed),
      spindleDir,
      spOutput.format(getCode("SELECT_SPINDLE", getSpindle(TOOL)))
    );
  } else {
    previousMaximumSpeed = 0; // reset for RPM spindle speeds
  }

  // enable SFM spindle speed
  if (forceRPMMode) {
    startSpindle(false, false);
  }

  if (machineState.usePolarInterpolation) {
    setPolarInterpolation(true); // enable polar interpolation mode
  }

  if (properties.miyano_useParametricFeed && !isDrillingCycle(true)) {
    if (!insertToolCall &&
      activeMovements &&
      (getCurrentSectionId() > 0) &&
      ((getPreviousSection().getPatternId() == currentSection.getPatternId()) && (currentSection.getPatternId() != 0))) {
      // use the current feeds
    } else {
      initializeActiveFeeds();
    }
  } else {
    activeMovements = undefined;
  }

  previousSpindle = tempSpindle;
  activeSpindle = tempSpindle;

  if (false) { // DEBUG
    for (var key in machineState) {
      writeComment(key + " : " + machineState[key]);
    }
    writeComment("Machining direction = " + machineState.machiningDirection);
    writeComment("Tapping = " + tapping);
    // writeln("(" + (getMachineConfigurationAsText(machineConfiguration)) + ")");
  }
}
function formatSubProgramNumber() {
  if (properties.miyano_subroutineAll && !showSequenceNumbers) {
    //if (!groupedOperations) {
    if (subroutineNumber > 99999) {
      subroutineNumber = subroutineStart;
    }
    var subno = "N" + subroutineNumber;
    subroutineNumber += subroutineNumberIncrement;
    writeBlock(subno);
    // }
  }
}
function safeStartSection(tempSpindle, newSpindle, abcValue) {
  formatSubProgramNumber();
  var plane = 18;
  // End the previous section if a new tool is selected
  //writeBlock(gFormat.format(40), gFormat.format(80), gFormat.format(plane) /*(machineState.usePolarMode ? gPlaneModal.format(17) : gPlaneModal.format(plane))*/, (tempSpindle == SPINDLE_LIVE ? gFeedModeModal.format(getCode("FEED_MODE_MM_MIN")) : gFeedModeModal.format(getCode("FEED_MODE_MM_REV"))));
  currentFeedMode = (tempSpindle == SPINDLE_LIVE ? 0 : 1);

  if (!partCutoff) {
    mInterferModal.reset();
    if (properties.miyano_optionalStop) {
      //onCommand(COMMAND_OPTIONAL_STOP);
      gMotionModal.reset();
    }
    //debugSectionHeader("onToolChange");
    // onToolChange(tempSpindle, abcValue);
  }

  // Cancel the reverse spindle code used in tapping
  if (reverseTap) {
    writeBlock(mFormat.format(177));
    reverseTap = false;
  }
}

function prepositionXYZ(position, abc) {
  var tempABC = new Vector(0, 0, abc.z);
  var W = machineConfiguration.getOrientation(tempABC);
  forceAny();
  writeBlock(gFormat.format(400), bOutput.format(getB(abc, currentSection)), "J" + spatialFormat.format(0));
  writeBlock(gMotionModal.format(0), cOutput.format(abc.z));

  var prePosition = W.getTransposed().multiply(position);
  writeBlock(gMotionModal.format(0), zOutput.format(prePosition.z));
  forceXYZ();
  writeBlock(gMotionModal.format(0), xOutput.format(prePosition.x), yOutput.format(prePosition.y), zOutput.format(prePosition.z));
  return true;
}

var MACHINING_DIRECTION_AXIAL = 0;
var MACHINING_DIRECTION_RADIAL = 1;
var MACHINING_DIRECTION_INDEXING = 2;

function getMachiningDirection(section) {
  var forward = section.workPlane.forward;
  if (section.isMultiAxis()) {
    forward = section.getGlobalInitialToolAxis();
    forward = Math.abs(forward.z) < 1e-7 ? new Vector(1, 0, 0) : forward; // radial multi-axis operation
  }
  if (isSameDirection(forward, new Vector(0, 0, 1))) {
    return MACHINING_DIRECTION_AXIAL;
  } else if (Vector.dot(forward, new Vector(0, 0, 1)) < 1e-7) {
    return MACHINING_DIRECTION_RADIAL;
  } else {
    return MACHINING_DIRECTION_INDEXING;
  }
}

/** Helper function to determine the polar machining options set in the user interface */
var IN_CONTROL = 0;
var IN_COMPUTER = 1;
function getOperationPolarMode(section) {
  var mode = undefined;
  if (revision >= 50294) {
    if (section.getParameter("operation:usePolarWhenNecessary", 0) == 1) {
      if (section.getParameter("operation:polarMode", false) == "computer") {
        mode = IN_COMPUTER;
      } else if (section.getParameter("operation:polarMode", false) == "control") {
        mode = IN_CONTROL;
      }
    } else if (section.polarMode && section.polarMode != POLAR_MODE_OFF) {
      if (section.getParameter("operation:polarMode", false) == "computer") {
        mode = IN_COMPUTER;
      } else if (section.getParameter("operation:polarMode", false) == "control") {
        mode = IN_CONTROL;
      } else { // automatic mode
        if (Vector.diff(defaultPolarCoordinatesDirection, section.polarDirection).length > 1e-4) {
          mode = IN_COMPUTER; // force polar coordinates when polarDirection is non zero in automatic mode
        } else {
          mode = gotPolarInterpolation ? IN_CONTROL : IN_COMPUTER; // use polar interpolation if available, otherwise polar coordinates
        }
      }
    }
  }
  return mode;
}

function updateMachiningMode(section) {
  if (!groupedOperations) {
    machineState.axialCenterDrilling = false; // reset
    machineState.usePolarInterpolation = false; // reset
    machineState.usePolarCoordinates = false; // reset

    machineState.machiningDirection = getMachiningDirection(section);
    var operationPolarMode = getOperationPolarMode(section); // determine the polar machining options set in the user interface
    if (operationPolarMode != undefined && (forcePolarCoordinates || forcePolarInterpolation)) {
      error("The Manual NC \"Action\" command to enable polar machining and the operation option \"Machining Type Polar\" cannot be used together." + EOL +
        "Please select only one option to enable polar machining.");
    }

    if ((section.getType() == TYPE_MILLING) && !section.isMultiAxis()) {
      if (machineState.machiningDirection == MACHINING_DIRECTION_AXIAL) {
        if (isDrillingCycle(section, false)) {
          // drilling axial
          machineState.axialCenterDrilling = isAxialCenterDrilling(section, true);
          if (!machineState.axialCenterDrilling && !isAxialCenterDrilling(section, false)) { // several holes not on XY center
            if (operationPolarMode != undefined) {
              if (operationPolarMode == IN_CONTROL) {
                warning(subst(localize("Polar mode \"In Control\" is not supported for drilling operation \"%1\". The post processor will use mode \"Automatic\" instead."), getOperationComment()));
              } else if (operationPolarMode == IN_COMPUTER) {
                machineState.usePolarCoordinates = true;
                polarCoordinatesDirection = section.polarDirection;
                if (properties.useYAxisForDrilling) {
                  warning(subst(localize("Polar mode was requested for operation \"%1\". Therefore, the post property \"" + properties.useYAxisForDrilling.title + "\" will be ignored."), getOperationComment()));
                }
              }
            } else {
              // bestABC = section.getABCByPreference(machineConfiguration, section.workPlane, getCurrentDirection(), C, PREFER_CLOSEST, ENABLE_RESET | ENABLE_LIMITS);
              bestABC = getBestABC(section);
              bestABC = section.doesToolpathFitWithinLimits(machineConfiguration, bestABC) ? bestABC : undefined;
              if (!properties.useYAxisForDrilling || bestABC == undefined) {
                machineState.usePolarCoordinates = true;
              }
            }
          }
        } else { // milling
          // Use new operation property for polar milling if available
          if (operationPolarMode != undefined) {
            forcePolarCoordinates = operationPolarMode == IN_COMPUTER;
            forcePolarInterpolation = operationPolarMode == IN_CONTROL;
            polarCoordinatesDirection = section.polarDirection;
          }
          if (gotPolarInterpolation && forcePolarInterpolation) { // polar mode is requested by user
            machineState.usePolarInterpolation = true;
            bestABC = undefined;
          } else if (forcePolarCoordinates) { // Polar coordinate mode is requested by user
            machineState.usePolarCoordinates = true;
            bestABC = undefined;
          } else {
            //bestABC = section.getABCByPreference(machineConfiguration, section.workPlane, getCurrentDirection(), C, PREFER_CLOSEST, ENABLE_RESET | ENABLE_LIMITS);
            bestABC = getBestABC(section);
            bestABC = section.doesToolpathFitWithinLimits(machineConfiguration, bestABC) ? bestABC : undefined;
            if (bestABC == undefined) { // toolpath does not match XY ranges, enable interpolation mode
              if (gotPolarInterpolation) {
                machineState.usePolarInterpolation = true;
              } else {
                machineState.usePolarCoordinates = true;
              }
            }
          }
        }
      } else if (machineState.machiningDirection == MACHINING_DIRECTION_RADIAL) { // G19 plane
        var range = section.getOptimizedBoundingBox(machineConfiguration, machineConfiguration.getABC(section.workPlane));
        var yAxisWithinLimits = machineConfiguration.getAxisY().getRange().isWithin(yFormat.getResultingValue(range.lower.y)) &&
          machineConfiguration.getAxisY().getRange().isWithin(yFormat.getResultingValue(range.upper.y));
        if (!gotYAxis) {
          if (!section.isMultiAxis() && !yAxisWithinLimits) {
            error(subst(localize("Y-axis motion is not possible without a Y-axis for operation \"%1\"."), getOperationComment()));
            return;
          }
        } else {
          if (!yAxisWithinLimits) {
            error(subst(localize("Toolpath exceeds the maximum ranges for operation \"%1\"."), getOperationComment()));
            return;
          }
        }
        // C-coordinates come from setWorkPlane or is within a multi axis operation, we cannot use the C-axis for non wrapped toolpathes (only multiaxis works, all others have to be into XY range)
      } else {
        // usePolarCoordinates & usePolarInterpolation is only supported for axial machining, keep false
      }
    } else {
      // turning or multi axis, keep false
    }

    if (machineState.axialCenterDrilling) {
      cOutput.disable();
    } else {
      cOutput.enable();
    }

    // validations
    if (forcePolarInterpolation && !gotPolarInterpolation) {
      warning(localize("Polar mode \"In Control\" has been requested but is either disabled or not supported by the machine." + EOL +
        "The post processor will use mode \"Automatic\" instead."));
    }
    if (machineState.usePolarCoordinates && section.getParameter("operation:compensationType", false) == "control") {
      error(subst(localize("Polar interpolation type \"In Control\" is required for using cutter compensation type \"In Control\" in operation \"%1\", but is either disabled or unsupported by the machine."), getOperationComment()));
    }
    var checksum = 0;
    checksum += machineState.usePolarInterpolation ? 1 : 0;
    checksum += machineState.usePolarCoordinates ? 1 : 0;
    checksum += machineState.axialCenterDrilling ? 1 : 0;
    validate(checksum <= 1, localize("Internal post processor error."));
  }
}

function getOperationComment() {
  var operationComment = hasParameter("operation-comment") && getParameter("operation-comment");
  return operationComment;
}

function setPolarInterpolation(activate) {
  if (activate) {
    cOutput.enable();
    var c = cOutput.format(0);
    if (c) {
      writeBlock(gMotionModal.format(0), c); // set C-axis to 0
    }
    writeBlock(gPolarModal.format(getCode("POLAR_INTERPOLATION_ON", getSpindle(PART)))); // command for polar interpolation
    writeBlock(gPlaneModal.format(17));
    if (getSpindle(PART) == SPINDLE_SUB) {
      invertAxes(true, true);
    } else {
      xOutput.setScale(2);
      yOutput.setScale(1);
      yOutput.setPrefix("C");
      yOutput.enable(); // required for G12.1
      cOutput.disable();
    }
  } else {
    writeBlock(gPolarModal.format(getCode("POLAR_INTERPOLATION_OFF", getSpindle(PART))));
    yOutput.setPrefix("Y");
    if (!gotYAxis) {
      yOutput.disable();
    }
    cOutput.enable();
    if (currentWorkPlaneABC != undefined) {
      currentWorkPlaneABC.z = Number.POSITIVE_INFINITY;
    }

  }
}

function goHome() {
  var yAxis = "";
  if (gotYAxis) {
    yAxis = "V" + yFormat.format(0);
  }
  //writeComment(gFormat.format(0) + "U" + xFormat.format(0) + "V" + xFormat.format(0) + "W" + xFormat.format(0) + " T00");
  writeBlock(gFormat.format(28), "U" + xFormat.format(0), yAxis);
  /*switch (getProperty("homeMethodZ")) {
  case "G28":
    //writeBlock(gMotionModal.format(0), gFormat.format(28), "W" + zFormat.format(0));
    zOutput.reset();
    break;
  case "G30":
    writeBlock(gMotionModal.format(0), gFormat.format(30), "W" + zFormat.format(0));
    zOutput.reset();
    break;
  case "G53":
    writeBlock(gMotionModal.format(0), gFormat.format(53), zOutput.format(getProperty("homePositionZ"));
    zOutput.reset();
    break;
  case "WCS":
    gMotionModal.reset();
    zOutput.reset();
    writeBlock(gMotionModal.format(0), zOutput.format(getProperty("homePositionZ")));
    break;
  default:
    error(localize("Unsupported method specified for Z-home positioning."));
  }*/
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  writeBlock(gFormat.format(4), dwellFormat.format(seconds));
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function getToolOffsetFactor(tool) {
  var turret = (!gotMultiTurret || tool.turret == 0) ? 1 : tool.turret;
  return (useExtendedOffsets == "both") || (turret == 1 && useExtendedOffsets == "main") ||
    (turret == 1 && useExtendedOffsets == "lower") ? 100 : 100;
}

function getCompensationPlane(abc, returnCode, outputPlane) {
  var plane;
  if (machineState.isTurningOperation) {
    plane = PLANE_ZX;
  } else if (machineState.usePolarInterpolation) {
    plane = PLANE_XY;
  } else {
    var found = false;
    if (useG368(abc)) {
      plane = PLANE_YZ; // use G19 for B-axis with 368 mode
      localZoutput = xOutput;
      found = true;
    }
    if (!found) {
      if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
        plane = PLANE_XY;
      } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
        plane = PLANE_YZ;
      } else {
        if (returnCode) {
          if (machineState.machiningDirection == MACHINING_DIRECTION_AXIAL) {
            plane = PLANE_XY;
          } else {
            plane = PLANE_ZX;
          }
        } else {
          plane = -1;
          if (outputPlane) {
            error(localize("Tool orientation is not supported for radius compensation."));
            return -1;
          }
        }
      }
    }
  }
  var code = plane == -1 ? -1 : (plane == PLANE_XY ? getG17Code() : (plane == PLANE_ZX ? 18 : 19));
  if (outputPlane) {
    writeBlock(gPlaneModal.format(code));
  }
  return returnCode ? code : plane;
}

var resetFeed = false;

function getHighfeedrate(radius) {
  if (currentSection.feedMode == FEED_PER_REVOLUTION) {
    if (toDeg(radius) <= 0) {
      radius = toPreciseUnit(0.1, MM);
    }
    var rpm = spindleSpeed; // rev/min
    if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      var O = 2 * Math.PI * radius; // in/rev
      rpm = tool.surfaceSpeed / O; // in/min div in/rev => rev/min
    }
    return highFeedrate / rpm; // in/min div rev/min => in/rev
  }
  return highFeedrate;
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    var useG1 = (((((((x ? 1 : 0) + (y ? 1 : 0) + (z ? 1 : 0)) > 1))) || machineState.usePolarInterpolation) && !isCannedCycle);
    var gCode = useG1 ? 1 : 0;
    var f = useG1 ? (getFeed(machineState.usePolarInterpolation ? toPreciseUnit(1500, MM) : getHighfeedrate(_x))) : "";
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      var plane = getCompensationPlane(getCurrentDirection(), false, true);
      var ccLeft = isMirrored(plane) ? 42 : 41;
      var ccRight = isMirrored(plane) ? 41 : 42;
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gMotionModal.format(gCode), gFormat.format(ccLeft), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gMotionModal.format(gCode), gFormat.format(ccRight), x, y, z, f);
        break;
      default:
        writeBlock(gMotionModal.format(gCode), gFormat.format(40), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(gCode), x, machineState.isTurningOperation ? "" : y, z, f);
      // removed Y for turning for Mitsubishi controller
      resetFeed = false;
    }
  }
}

function onLinear(_x, _y, _z, feed) {
  if (isSpeedFeedSynchronizationActive()) {
    resetFeed = true;
    var threadPitch = getParameter("operation:threadPitch");
    var threadsPerInch = 1.0 / threadPitch; // per mm for metric
    writeBlock(gMotionModal.format(32), xOutput.format(_x), yOutput.format(_y), zOutput.format(_z), pitchOutput.format(1 / threadsPerInch));
    return;
  }
  if (resetFeed) {
    resetFeed = false;
    forceFeed();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      var plane = getCompensationPlane(getCurrentDirection(), false, true);
      var ccLeft = isMirrored(plane) ? 42 : 41;
      var ccRight = isMirrored(plane) ? 41 : 42;
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(
          gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1),
          gFormat.format(ccLeft),
          x, y, z, getFeed(feed)
        );
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(
          gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1),
          gFormat.format(ccRight),
          x, y, z, getFeed(feed)
        );
        break;
      default:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(40), x, y, z, getFeed(feed));
      }
    } else {
      writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), x, machineState.isTurningOperation ? "" : y, z, getFeed(feed));
      //Mitsubishi controllers aren't keen on Y in turning - doesnt complain, but does a weird move
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  if (x || y || z || a || b || c) {
    var useG1 = (((((x ? 1 : 0) + (y ? 1 : 0) + (z ? 1 : 0) + (a ? 1 : 0) + (b ? 1 : 0) + (c ? 1 : 0) > 1))));
    var gCode = useG1 ? 1 : 0;
    var f = useG1 ? (getFeed(machineState.usePolarInterpolation ? toPreciseUnit(1500, MM) : getHighfeedrate(_x))) : "";
    writeBlock(gMotionModal.format(gCode), x, y, z, a, b, c, f);
    if (!useG1) {
      forceFeed();
    }
  }
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);

  if (x || y || z || a || b || c) {
    writeBlock(gMotionModal.format(1), x, y, z, a, b, c, getFeed(feed));
  }
}

// Start of Polar coordinates
var defaultPolarCoordinatesDirection = new Vector(1, 0, 0); // default direction for polar interpolation
var polarCoordinatesDirection = defaultPolarCoordinatesDirection; // vector to maintain tool at while in polar interpolation
var polarSpindleAxisSave;
function setPolarCoordinates(mode) {
  if (!mode) { // turn off polar mode if required
    if (isPolarModeActive()) {
      deactivatePolarMode();
      if (gotBAxis) {
        machineConfiguration.setSpindleAxis(polarSpindleAxisSave);
        bOutput.enable();
      }
      // setPolarFeedMode(false);
      if (currentWorkPlaneABC != undefined) {
        currentWorkPlaneABC.z = Number.POSITIVE_INFINITY;
      }
    }
    polarCoordinatesDirection = defaultPolarCoordinatesDirection; // reset when deactivated
    return;
  }

  var direction = polarCoordinatesDirection;

  // determine the rotary axis to use for Polar coordinates
  var axis = undefined;
  if (machineConfiguration.getAxisV().isEnabled()) {
    if (Vector.dot(machineConfiguration.getAxisV().getAxis(), currentSection.workPlane.getForward()) != 0) {
      axis = machineConfiguration.getAxisV();
    }
  }
  if (axis == undefined && machineConfiguration.getAxisU().isEnabled()) {
    if (Vector.dot(machineConfiguration.getAxisU().getAxis(), currentSection.workPlane.getForward()) != 0) {
      axis = machineConfiguration.getAxisU();
    }
  }
  if (axis == undefined) {
    error(localize("Polar coordinates require an active rotary axis be defined in direction of workplane normal."));
  }

  // calculate directional vector from initial position
  if (direction == undefined) {
    error(localize("Polar coordinates initiated without a directional vector."));
    return;
  }

  // activate polar coordinates
  // setPolarFeedMode(true); // enable multi-axis feeds for polar mode

  if (gotBAxis) {
    polarSpindleAxisSave = machineConfiguration.getSpindleAxis();
    machineConfiguration.setSpindleAxis(new Vector(0, 0, 1));
    bOutput.disable();
  }
  activatePolarMode(getTolerance() / 2, 0, direction);
  var polarPosition = getPolarPosition(currentSection.getInitialPosition().x, currentSection.getInitialPosition().y, currentSection.getInitialPosition().z);
  setCurrentPositionAndDirection(polarPosition);
}

function getPolarCoordinates(position, abc) {
  var reset = false;
  var current = getCurrentDirection();
  if (!isPolarModeActive()) {
    setCurrentDirection(abc);
    var tempPolarCoordinatesDirection = (currentSection.machiningType && (currentSection.machiningType == MACHINING_TYPE_POLAR)) ? currentSection.polarDirection : polarCoordinatesDirection;
    activatePolarMode(getTolerance() / 2, 0, tempPolarCoordinatesDirection);
    reset = true;
  }
  var polarPosition = getPolarPosition(position.x, position.y, position.z);
  if (reset) {
    deactivatePolarMode();
    setCurrentDirection(current);
  }
  return polarPosition;
}
// End of polar coordinates

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var directionCode;
  if (isMirrored(getCircularPlane())) {
    directionCode = clockwise ? 3 : 2;
  } else {
    directionCode = clockwise ? 2 : 3;
  } 
  if (getSpindle(PART) == SPINDLE_SUB && (turretNum == 1 || turretNum == 2) ) {
    if (machineState.subSpindleIsActive) {
      directionCode = clockwise ? 3 : 2;
    } else {
      directionCode = clockwise ? 2 : 3;
    }
  }
  if (getSpindle(PART) == SPINDLE_MAIN && turretNum == 1 ) {
    if (machineState.usePolarCoordinates || machineState.usePolarInterpolation) {
      directionCode = clockwise ? 2 : 3;
    } else {
      if (machineState.mainSpindleIsActive) {
        directionCode = clockwise ? 2 : 3;
      } else {
        directionCode = clockwise ? 3 : 2;
      }
    }
  }
  var toler = getTolerance();

  if (isSpeedFeedSynchronizationActive()) {
    error(localize("Speed-feed synchronization is not supported for circular moves."));
    return;
  }

  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (properties.miyano_useRadius || isHelical()) { // radius mode does not support full arcs
      linearize(toler);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(getG17Code()), gMotionModal.format(directionCode), iOutput.format(cx - start.x), jOutput.format(cy - start.y), getFeed(feed));
      break;
    case PLANE_ZX:
      if (machineState.usePolarInterpolation) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(directionCode), iOutput.format(cx - start.x), kOutput.format(cz - start.z), getFeed(feed));
      break;
    case PLANE_YZ:
      if (machineState.usePolarInterpolation) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(directionCode), jOutput.format(cy - start.y), kOutput.format(cz - start.z), getFeed(feed));
      break;
    default:
      linearize(toler);
    }
  } else if (!properties.miyano_useRadius) {
    if (isHelical() && ((getCircularSweep() < toRad(30)) || (getHelicalPitch() > 10))) { // avoid G112 issue
      linearize(toler);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(getG17Code()), gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x), jOutput.format(cy - start.y), getFeed(feed));
      break;
    case PLANE_ZX:
      if (machineState.usePolarInterpolation) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x), kOutput.format(cz - start.z), getFeed(feed));
      break;
    case PLANE_YZ:
      if (machineState.usePolarInterpolation) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y), kOutput.format(cz - start.z), getFeed(feed));
      break;
    default:
      linearize(toler);
    }
  } else { // use radius mode
    if (isHelical() && ((getCircularSweep() < toRad(30)) || (getHelicalPitch() > 10))) {
      linearize(toler);
      return;
    }
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(getG17Code()), gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_ZX:
      if (machineState.usePolarInterpolation) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_YZ:
      if (machineState.usePolarInterpolation) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    default:
      linearize(toler);
    }
  }
}

var chuckMachineFrame;
var chuckSubPosition;
function getSecondaryPullMethod(type) {
  var pullMethod = {};

  // determine if pull operation, spindle return, or both
  pullMethod.pull = false;
  pullMethod.home = false;

  switch (type) {
  case "secondary-spindle-pull":
    pullMethod.pullPosition = chuckSubPosition + cycle.pullingDistance;
    pullMethod.machineFrame = chuckMachineFrame;
    pullMethod.unclampMode = "keep-clamped";
    pullMethod.pull = true;
    break;
  case "secondary-spindle-return":
    pullMethod.pullPosition = cycle.feedPosition;
    pullMethod.machineFrame = cycle.useMachineFrame;
    pullMethod.unclampMode = cycle.unclampMode;

    // pull part only (when offset!=0), Return secondary spindle to home (when offset=0)
    var feedDis = 0;
    if (pullMethod.machineFrame) {
      if (hasParameter("operation:feedPlaneHeight_direct")) { // Inventor
        feedDis = getParameter("operation:feedPlaneHeight_direct");
      } else if (hasParameter("operation:feedPlaneHeightDirect")) { // HSMWorks
        feedDis = getParameter("operation:feedPlaneHeightDirect");
      }
      feedPosition = feedDis;
    } else if (hasParameter("operation:feedPlaneHeight_offset")) { // Inventor
      feedDis = getParameter("operation:feedPlaneHeight_offset");
    } else if (hasParameter("operation:feedPlaneHeightOffset")) { // HSMWorks
      feedDis = getParameter("operation:feedPlaneHeightOffset");
    }

    // Transfer part to secondary spindle
    if (pullMethod.unclampMode != "keep-clamped") {
      pullMethod.pull = feedDis != 0;
      pullMethod.home = true;
    } else {
      // pull part only (when offset!=0), Return secondary spindle to home (when offset=0)
      pullMethod.pull = feedDis != 0;
      pullMethod.home = !pullMethod.pull;
    }
    break;
  }
  return pullMethod;
}

function onCycle() {
  if ((typeof isSubSpindleCycle == "function") && isSubSpindleCycle(cycleType)) {
    if (!gotSecondarySpindle) {
      error(localize("Secondary spindle is not available."));
    }

    writeln("");
    if (hasParameter("operation-comment")) {
      var comment = getParameter("operation-comment");
      if (comment) {
        writeComment(comment);
      }
    }

    // Start of stock transfer operation(s)
    /*   if (!machineState.stockTransferIsActive) {
         if (cycleType != "secondary-spindle-return" && cycleType != "secondary-spindle-pull") {
           moveSubSpindle(HOME, 0, 0, true, "SUB SPINDLE RETURN", false);
           goHome();
         }
         onCommand(COMMAND_STOP_SPINDLE);
         onCommand(COMMAND_COOLANT_OFF);
         onCommand(COMMAND_OPTIONAL_STOP);
         forceUnlockMultiAxis();
         onCommand(COMMAND_UNLOCK_MULTI_AXIS);
         gFeedModeModal.reset();
         var feedMode = gFeedModeModal.format(getCode("FEED_MODE_UNIT_MIN", getSpindle(TOOL)));
         gPlaneModal.reset();
         if (!getProperty("optimizeCAxisSelect")) {
           cAxisEngageModal.reset();
         }
         writeBlock(feedMode, gPlaneModal.format(18), cAxisEngageModal.format(getCode("DISABLE_C_AXIS", getSpindle(PART))));
         writeBlock(mFormat.format(getCode("DISABLE_C_AXIS", getSecondarySpindle())));
       }*/

    // switch (cycleType) {
    /*  case "secondary-spindle-grab":
          // Activate part catcher for part cutoff section
         // if (getProperty("usePartCatcher") && partCutoff && currentSection.partCatcher) {
          //  engagePartCatcher(true);
         // }
          writeBlock(mFormat.format(getCode("INTERLOCK_BYPASS", getSecondarySpindle())), formatComment("INTERLOCK BYPASS"));
          clampChuck(getSecondarySpindle(), UNCLAMP);
          onDwell(cycle.dwell);
          gSpindleModeModal.reset();

          if (cycle.stopSpindle) { // no spindle rotation
            lastSpindleSpeed = 0;
          } else { // spindle rotation
            var transferCodes = getSpindleTransferCodes(transferType);

            // Write out maximum spindle speed
            if (transferCodes.spindleMode == SPINDLE_CONSTANT_SURFACE_SPEED) {
              var maximumSpindleSpeed = (transferCodes.maximumSpindleSpeed > 0) ? Math.min(transferCodes.maximumSpindleSpeed, getProperty("maximumSpindleSpeed")) : getProperty("maximumSpindleSpeed");
              writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
              sOutput.reset();
            }
            // write out spindle speed
            var _spindleSpeed;
            var spindleMode;
            if (transferCodes.spindleMode == SPINDLE_CONSTANT_SURFACE_SPEED) {
              _spindleSpeed = transferCodes.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0);
              spindleMode = getCode("CONSTANT_SURFACE_SPEED_ON", getSpindle(PART));
            } else {
              _spindleSpeed = cycle.spindleSpeed;
              spindleMode = getCode("CONSTANT_SURFACE_SPEED_OFF", getSpindle(PART));
            }
            var comment;
            if (transferType == TRANSFER_PHASE) {
              comment = "PHASE SYNCHRONIZATION";
            } else {
              comment = "SPEED SYNCHRONIZATION";
            }
            writeBlock(
              gSpindleModeModal.format(spindleMode),
              sOutput.format(_spindleSpeed),
              mFormat.format(transferCodes.direction),
              spOutput.format(getCode("SELECT_SPINDLE", getSpindle(PART))),
              formatComment(comment)
            );
            lastSpindleMode = transferCodes.spindleMode;
            lastSpindleSpeed = _spindleSpeed;
            lastSpindleDirection = transferCodes.spindleDirection;
          }

          // clean out chips
          if (airCleanChuck) {
            writeBlock(mFormat.format(getCode("AIR_BLAST_ON", SPINDLE_MAIN)), formatComment("CLEAN OUT CHIPS"));
            writeBlock(mFormat.format(getCode("AIR_BLAST_ON", SPINDLE_SUB)));
            onDwell(5.5);
            writeBlock(mFormat.format(getCode("AIR_BLAST_OFF", SPINDLE_MAIN)));
            writeBlock(mFormat.format(getCode("AIR_BLAST_OFF", SPINDLE_SUB)));
          }

          writeBlock(mInterferModal.format(getCode("INTERFERENCE_CHECK_OFF", getSpindle(PART))));

          // need to orientate spindle after cleaning out chips, since spindles rotate during coolant air
          transferOrientation = 0;
          if (cycle.stopSpindle) {
            transferOrientation = (cycle.spindleOrientation != undefined) ? cycle.spindleOrientation : transferOrientation;
            writeBlock(mFormat.format(getCode("ENABLE_C_AXIS", getSpindle(PART))));
            writeBlock(cAxisBrakeModal.format(getCode("UNLOCK_MULTI_AXIS", getSpindle(PART))));
            writeBlock(gMotionModal.format(0), gFormat.format(53), "C" + abcFormat.format(0));
            writeBlock(mFormat.format(getCode("ENABLE_C_AXIS", getSecondarySpindle())));
            writeBlock(gMotionModal.format(0), gFormat.format(53), "C" + abcFormat.format(transferOrientation));
            forceTurningMode = true;
          }
          gMotionModal.reset();
          moveSubSpindle(RAPID, cycle.feedPosition, 0, cycle.useMachineFrame, "", true);

          if (transferUseTorque) {
            writeBlock(mFormat.format(getCode("TORQUE_SKIP_ON", getSpindle(PART))), formatComment("TORQUE SKIP ON"));
            moveSubSpindle(TORQUE, cycle.chuckPosition, cycle.feedrate, cycle.useMachineFrame, "", true);
            writeBlock(mFormat.format(getCode("TORQUE_SKIP_OFF", getSpindle(PART))), formatComment("TORQUE SKIP OFF"));
          } else {
            moveSubSpindle(FEED, cycle.chuckPosition, cycle.feedrate, cycle.useMachineFrame, "", true);
          }
          clampChuck(getSecondarySpindle(), CLAMP);
          writeBlock(mFormat.format(getCode("INTERLOCK_BYPASS", getSpindle(PART))), formatComment("INTERLOCK BYPASS"));

          onDwell(cycle.dwell);
          chuckMachineFrame = cycle.useMachineFrame;
          chuckSubPosition = cycle.chuckPosition;
          machineState.stockTransferIsActive = true;
          break;
        case "secondary-spindle-return":
        case "secondary-spindle-pull":
          var pullMethod = getSecondaryPullMethod(cycleType);
          if (!machineState.stockTransferIsActive) {
            if (pullMethod.pull) {
              error(localize("The part must be chucked prior to a pull operation."));
              return;
            }
          }
          writeBlock(mFormat.format(getCode("INTERLOCK_BYPASS", getSecondarySpindle())));

          // bar pull
          if (pullMethod.pull) {
            clampChuck(getSpindle(PART), UNCLAMP);
            onDwell(cycle.dwell);
            moveSubSpindle(FEED, pullMethod.pullPosition, cycle.feedrate, pullMethod.machineFrame, "BAR PULL", true);
          }

          // move subspindle to home
          if (pullMethod.home) {
            if (pullMethod.unclampMode == "unclamp-secondary") { // leave part in main spindle
              clampChuck(getSpindle(PART), CLAMP);
              onDwell(cycle.dwell);
              clampChuck(getSecondarySpindle(), UNCLAMP);
              onDwell(cycle.dwell);
            } else if (pullMethod.unclampMode == "unclamp-primary") {
              clampChuck(getSpindle(PART), UNCLAMP);
              onDwell(cycle.dwell);
            }
            moveSubSpindle(HOME, 0, 0, true, "SUB SPINDLE RETURN", true);
          } else {
            clampChuck(getSpindle(PART), CLAMP);
            onDwell(cycle.dwell);
            // writeBlock(mFormat.format(getCode("COOLANT_THROUGH_TOOL_OFF", getSecondarySpindle())));
            mInterferModal.reset();
            writeBlock(mInterferModal.format(getCode("INTERFERENCE_CHECK_OFF", getSpindle(PART))));
          }
          machineState.stockTransferIsActive = true;
          break;*/
  //  }
  }

  if (cycleType == "stock-transfer") {
    warning(localize("Stock transfer is not supported. Required machine specific customization."));
    return;
  } else if (!properties.useCycles && tapping) {
    //startSpindle(false, false);
  }
}

var saveShowSequenceNumbers;
var pathBlockNumber = {start:0, end:0};
var isCannedCycle = false;

function onCyclePath() {
  saveShowSequenceNumbers = showSequenceNumbers;
  isCannedCycle = true;
  // buffer all paths and stop feeds being output
  feedOutput.disable();
  showSequenceNumbers = "false";
  redirectToBuffer();
  gMotionModal.reset();
  xOutput.reset();
  zOutput.reset();
}

function onCyclePathEnd() {
  showSequenceNumbers = saveShowSequenceNumbers; // reset property to initial state
  feedOutput.enable();
  var cyclePath = String(getRedirectionBuffer()).split(EOL); // get cycle path from buffer
  closeRedirection();
  for (line in cyclePath) { // remove empty elements
    if (cyclePath[line] == "") {
      cyclePath.splice(line);
    }
  }

  var verticalPasses;
  if (cycle.profileRoughingCycle == 0) {
    verticalPasses = false;
  } else if (cycle.profileRoughingCycle == 1) {
    verticalPasses = true;
  } else {
    error(localize("Unsupported passes type."));
    return;
  }
  // output cycle data
  switch (cycleType) {
  case "turning-canned-rough":
    writeBlock(gFormat.format(verticalPasses ? 72 : 71),
      (verticalPasses ? "W" : "U") + spatialFormat.format(cycle.depthOfCut),
      "R" + spatialFormat.format(cycle.retractLength)
    );
    writeBlock(gFormat.format(verticalPasses ? 72 : 71),
      "P" + (getStartEndSequenceNumber(cyclePath, true)),
      "Q" + (getStartEndSequenceNumber(cyclePath, false)),
      "U" + xFormat.format(cycle.xStockToLeave),
      "W" + spatialFormat.format(cycle.zStockToLeave),
      getFeed(cycle.cutfeedrate)
    );
    break;
  default:
    error(localize("Unsupported turning canned cycle."));
  }

  for (var i = 0; i < cyclePath.length; ++i) {
    if (i == 0 || i == (cyclePath.length - 1)) { // write sequence number on first and last line of the cycle path
      showSequenceNumbers = "true";
      if ((i == 0 && pathBlockNumber.start != sequenceNumber) || (i == (cyclePath.length - 1) && pathBlockNumber.end != sequenceNumber)) {
        error(localize("Mismatch of start/end block number in turning canned cycle."));
        return;
      }
    }
    writeBlock(cyclePath[i]); // output cycle path
    showSequenceNumbers = saveShowSequenceNumbers; // reset property to initial state
    isCannedCycle = false;
  }
}

function getStartEndSequenceNumber(cyclePath, start) {
  if (start) {
    pathBlockNumber.start = sequenceNumber + conditional(saveShowSequenceNumbers == "true", properties.miyano_sequenceNumberIncrement);
    return pathBlockNumber.start;
  } else {
    pathBlockNumber.end = sequenceNumber + properties.miyano_sequenceNumberIncrement + conditional(saveShowSequenceNumbers == "true", (cyclePath.length - 1) * properties.miyano_sequenceNumberIncrement);
    return pathBlockNumber.end;
  }
}

function getCommonCycle(x, y, z, r, includeRcode) {

  // R-value is incremental position from current position
  var raptoS = "";
  if ((r !== undefined) && includeRcode) {
    raptoS = "R" + spatialFormat.format(r);
  }

  if (machineState.usePolarCoordinates) {
    var polarPosition = getPolarPosition(x, y, z);
    setCurrentPositionAndDirection(polarPosition);
    cOutput.reset();
    return [xOutput.format(polarPosition.first.x), cOutput.format(polarPosition.second.z),
      zOutput.format(polarPosition.first.z),
      raptoS];
  } else {
    return [xOutput.format(x), yOutput.format(y),
      zOutput.format(z),
      raptoS];
  }
}

function writeCycleClearance(plane, clearance) {
  var currentPosition = getCurrentPosition();
  if (true) {
    //onCycleEnd();
    switch (plane) {
    case 17:
      writeBlock(gMotionModal.format(0), zOutput.format(clearance));
      break;
    case 18:
      writeBlock(gMotionModal.format(0), yOutput.format(clearance));
      break;
    case 19:
      writeBlock(gMotionModal.format(0), xOutput.format(clearance));
      break;
    default:
      error(localize("Unsupported drilling orientation."));
      return;
    }
  }
}

var threadStart;
var threadEnd;
function moveToThreadStart(x, y, z) {
  var cuttingAngle = 0;
  if (hasParameter("operation:infeedAngle")) {
    cuttingAngle = getParameter("operation:infeedAngle");
  }
  if (cuttingAngle != 0) {
    var zz;
    if (isFirstCyclePoint()) {
      threadStart = getCurrentPosition();
      threadEnd = new Vector(x, y, z);
    } else {
      var zz = threadStart.z - (Math.abs(threadEnd.x - x) * Math.tan(toRad(cuttingAngle)));
      writeBlock(gMotionModal.format(0), zOutput.format(zz));
      threadStart.setZ(zz);
      threadEnd = new Vector(x, y, z);
    }
  }
}

function onCyclePoint(x, y, z) {
  if (currentSection.isMultiAxis()) {
    expandCyclePoint(x, y, z);
    return;
  }

  var plane = gPlaneModal.getCurrent();
  var localZOutput = zOutput;
  var cycleAxis = currentSection.workPlane.forward;
  var found = false;
  if ((gotBAxis && (activeTurret != 2)) && !bAxisIsManual) {
    if (!getTCP(getCurrentDirection()) && useG368(getCurrentDirection())) {
      plane = 19; // use G19 for B-axis with 368 mode
      localZoutput = xOutput;
      found = true;
    }
  }
  if (!found) {
    if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1)) ||
      isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
      plane = 17; // XY plane
      localZOutput = zOutput;
    } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
      plane = 19; // YZ plane
      localZOutput = xOutput;
    } else if ((gotBAxis && (activeTurret != 2)) && !bAxisIsManual) {
      plane = 19;  // use G19 for B-axis when outside major plane
      localZoutput = xOutput;
    } else if (gotBAxis && (activeTurret != 2)) { // manual B-axis
      if (!useMultiAxisFeatures) {
        if (tapping) {
          writeBlock(mFormat.format(48)); // lock feedrate overrides
        }
        expandCyclePoint(x, y, z);
        if (tapping) {
          writeBlock(mFormat.format(49)); // unlock feedrate overrides
        }
        return;
      } else if (isSameDirection(machineConfiguration.getSpindleAxis(), new Vector(0, 0, 1)) ||
        isSameDirection(machineConfiguration.getSpindleAxis(), new Vector(0, 0, -1))) {
        plane = 17; // XY plane
        localZOutput = zOutput;
      } else if (Vector.dot(machineConfiguration.getSpindleAxis(), new Vector(0, 0, 1)) < 1e-7) {
        plane = 19; // YZ plane
        localZOutput = xOutput;
      } else {
        if (tapping) {
          error(localize("Tapping cycles cannot be expanded."));
          return;
        }
        expandCyclePoint(x, y, z);
        return;
      }
    } else {
      if (tapping) {
        error(localize("Tapping cycles cannot be expanded."));
        return;
      }
      expandCyclePoint(x, y, z);
      return;
    }
  }

  switch (cycleType) {
  case "thread-turning":
    if (properties.useSimpleThread ||
        (hasParameter("operation:doMultipleThreads") && (getParameter("operation:doMultipleThreads") != 0)) ||
        (hasParameter("operation:infeedMode") && (getParameter("operation:infeedMode") != "constant"))) {
      var r = -cycle.incrementalX; // positive if taper goes down - delta radius
      moveToThreadStart(x, y, z);
      xOutput.reset();
      zOutput.reset();
      writeBlock(
        gMotionModal.format(92),
        xOutput.format(x),
        yOutput.format(y),
        zOutput.format(z),
        conditional(zFormat.isSignificant(r), g92ROutput.format(r)),
        pitchOutput.format(cycle.pitch)
      );
    } else {
      if (isLastCyclePoint()) {
        // thread height and depth of cut
        var threadHeight = getParameter("operation:threadDepth");
        var stepdowns = [];
        for (var i = 0; i < getNumberOfCyclePoints() - 1; i++) {
          stepdowns.push(Math.abs(getCyclePoint(i).x - getCyclePoint(i + 1).x));
        }
        var minimumDepthOfCut = Math.min.apply(null, stepdowns.filter(Boolean));
        var firstDepthOfCut = cycle.firstPassDepth ? cycle.firstPassDepth : threadHeight - Math.abs(getCyclePoint(0).x - x);

        // first G76 block
        var repeatPass = hasParameter("operation:nullPass") ? getParameter("operation:nullPass") : 0;
        var chamferWidth = 10; // Pullout-width is 1*thread-lead in 1/10's;
        var materialAllowance = 0; // Material allowance for finishing pass
        var cuttingAngle = getParameter("operation:infeedAngle", 30) * 2; // Angle is not stored with tool. toDeg(tool.getTaperAngle());
        var pcode = repeatPass * 10000 + chamferWidth * 100 + cuttingAngle;
        gCycleModal.reset();
        writeBlock(
          gCycleModal.format(76),
          threadP1Output.format(pcode),
          threadQOutput.format(minimumDepthOfCut),
          threadROutput.format(materialAllowance)
        );

        // second G76 block
        var r = -cycle.incrementalX; // positive if taper goes down - delta radius
        gCycleModal.reset();
        writeBlock(
          gCycleModal.format(76),
          xOutput.format(x),
          zOutput.format(z),
          conditional(zFormat.isSignificant(r), threadROutput.format(r)),
          threadP2Output.format(threadHeight),
          threadQOutput.format(firstDepthOfCut),
          pitchOutput.format(cycle.pitch)
        );
      }
    }
    forceFeed();
    return;
  }

  // clamp the C-axis if necessary
  // the C-axis is automatically unclamped by the controllers during cycles
  var lockCode = "";
  if (!machineState.axialCenterDrilling && !machineState.isTurningOperation && ((plane == 19) || machineState.usePolarCoordinates)) {
    lockCode = mFormat.format(getCode("LOCK_MULTI_AXIS", getSpindle(PART)));
  }

  var rapto = 0;
  if (isFirstCyclePoint()) { // first cycle point
    rapto = (getSpindle(PART) == SPINDLE_SUB && machineState.machiningDirection == MACHINING_DIRECTION_AXIAL) ? cycle.clearance - cycle.retract : cycle.retract - cycle.clearance;

    var P = !cycle.dwell ? 0 : clamp(1, cycle.dwell * 1000, 99999999); // in milliseconds

    switch (cycleType) {
    case "drilling":
    case "counter-boring":
      //writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      writeBlock(
        gCycleModal.format(plane == 19 ? 87 : 83),
        getCommonCycle(x, y, z, rapto, true),
        conditional(P > 0, pOutput.format(P)),
        getFeed(cycle.feedrate)//,
        // lockCode
      );
      break;
    case "chip-breaking":
      if (cycle.accumulatedDepth < cycle.depth) {
        expandCyclePoint(x, y, z);
      } else {
        writeCycleClearance(plane, cycle.clearance);
        localZOutput.reset();
        writeBlock(
          gCycleModal.format(plane == 19 ? 87 : 83),
          getCommonCycle(x, y, z, rapto, true),
          conditional(cycle.incrementalDepth > 0, peckOutput.format(cycle.incrementalDepth)),
          conditional(P > 0, pOutput.format(P)),
          getFeed(cycle.feedrate)//,
          //lockCode
        );
      }
      break;
    case "deep-drilling":
      //writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      writeBlock(
        gCycleModal.format(plane == 19 ? 87 : 83),
        getCommonCycle(x, y, z, rapto, true),
        conditional(cycle.incrementalDepth > 0, peckOutput.format(cycle.incrementalDepth)),
        conditional(P > 0, pOutput.format(P)),
        getFeed(cycle.feedrate)//,
        // lockCode
      );
      break;
    case "tapping":
    case "right-tapping":
    case "left-tapping":
      writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      //startSpindle(true, false);
      writeBlock(gFeedModeModal.format(getCode("FEED_MODE_UNIT_REV", getSpindle(TOOL))));
      if (tool.type == TOOL_TAP_LEFT_HAND) {
        writeBlock(mTappingModal.format(176));
      }
      writeBlock(
        gCycleModal.format(plane == 19 ? 88 : 84),
        getCommonCycle(x, y, z, rapto, true),
        conditional(P > 0, pOutput.format(P)),
        getFeed(cycle.feedrate)//,
        //lockCode
      );
      break;
    case "tapping-with-chip-breaking":
      writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      startSpindle(true, false);
      writeBlock(gFeedModeModal.format(getCode("FEED_MODE_UNIT_REV", getSpindle(TOOL))));
      if (tool.type == TOOL_TAP_LEFT_HAND) {
        writeBlock(mTappingModal.format(176));
      }
      writeBlock(
        gCycleModal.format(plane == 19 ? 88 : 84),
        getCommonCycle(x, y, z, rapto, true),
        conditional(cycle.incrementalDepth > 0, peckOutput.format(cycle.incrementalDepth)),
        conditional(P > 0, pOutput.format(P)),
        getFeed(cycle.feedrate)//,
        //lockCode
      );
      break;
    case "boring":
      if (feedFormat.getResultingValue(cycle.feedrate) != feedFormat.getResultingValue(cycle.retractFeedrate)) {
        expandCyclePoint(x, y, z);
        break;
      }
      writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      writeBlock(
        gCycleModal.format(plane == 19 ? 89 : 85),
        getCommonCycle(x, y, z, rapto, true),
        conditional(P > 0, pOutput.format(P)),
        getFeed(cycle.feedrate)//,
        // lockCode
      );
      break;
    default:
      expandCyclePoint(x, y, z);
    }
  } else { // position to subsequent cycle points
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      var step = 0;
      if (cycleType == "chip-breaking" || cycleType == "deep-drilling") {
        step = cycle.incrementalDepth;
      }
      if (machineState.usePolarCoordinates) {
        //writeBlock(mFormat.format(getCode("UNLOCK_MULTI_AXIS", getSpindle(PART))));
      }
      writeBlock(getCommonCycle(x, y, z, rapto, false), conditional(step > 0, peckOutput.format(step)));//, lockCode);
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded && !machineState.stockTransferIsActive) {
    // reset feed rate mode, cancel cycle, cancel reverse tapping
    writeBlock(gCycleModal.format(80), mTappingModal.format(177));
    cAxisBrakeModal.format(getCode("LOCK_MULTI_AXIS", getSpindle(PART))); // canned cycles lock the C-axis
    gMotionModal.reset();
  }
}

function onPassThrough(text) {
  var commands = String(text).split(",");
  for (text in commands) {
    writeBlock(commands[text]);
  }
}
let closedSection = false;
function onParameter(name, value) {
  var invalid = false;
  switch (name) {
  case "action":
    if (String(value).toUpperCase() == "PARTEJECT") {
      ejectRoutine = true;
    } else if (String(value).toUpperCase() == "USEPOLARMODE" ||
        String(value).toUpperCase() == "USEPOLARINTERPOLATION") {
      forcePolarInterpolation = true;
      forcePolarCoordinates = false;
    } else if (String(value).toUpperCase() == "USEXZCMODE" ||
        String(value).toUpperCase() == "USEPOLARCOORDINATES") {
      forcePolarCoordinates = true;
      forcePolarInterpolation = false;
    } else if (String(value).toUpperCase() == "STARTGROUP") {

      shouldRedirect = false;
      redirectStarted = false;
      groupedOperations = true;
    } else if (String(value).toUpperCase() == "ENDGROUP") {
      closeSection();
      shouldRedirect = true;
      redirectStarted = false;
      groupedOperations = false;
      machineState.axialCenterDrilling = false; // reset
      machineState.usePolarMode = false; // reset
      machineState.useXZCMode = false; // reset

    } else {
      var sText1 = String(value);
      var sText2 = new Array();
      sText2 = sText1.split(":");
      if (sText2.length != 2) {
        error(localize("Invalid action command: ") + value);
        return;
      }
      /*if (sText2[0].toUpperCase() == "TRANSFERTYPE") {
          transferType = parseToggle(sText2[1], "PHASE", "SPEED");
          if (transferType == undefined) {
            error(localize("TransferType must be Phase or Speed"));
            return;
          }
        } else if (sText2[0].toUpperCase() == "TRANSFERUSETORQUE") {
          transferUseTorque = parseToggle(sText2[1], "YES", "NO");
          if (transferUseTorque == undefined) {
            invalid = true;
          }
        } else if (sText2[0].toUpperCase() == "USETAILSTOCK") {
          forceTailStock = parseToggle(sText2[1], "YES", "NO");
          if (forceTailStock == undefined) {
            invalid = true;
          }
        }*/
      if (sText2[0].toUpperCase() == "SYNCSPINDLESTART") {
        syncStartMethod = parseToggle(sText2[1], "ERROR", "UNCLAMP", "SPEED");
        if (syncStartMethod == undefined) {
          invalid = true;
        }
      } else {
        invalid = true;
      }
    }
  }
  if (invalid) {
    error(localize("Invalid action parameter: ") + sText2[0] + ":" + sText2[1]);
    return;
  }
}

function parseToggle() {
  var stat = undefined;
  for (i = 1; i < arguments.length; i++) {
    if (String(arguments[0]).toUpperCase() == String(arguments[i]).toUpperCase()) {
      if (String(arguments[i]).toUpperCase() == "YES") {
        stat = true;
      } else if (String(arguments[i]).toUpperCase() == "NO") {
        stat = false;
      } else {
        stat = i - 1;
        break;
      }
    }
  }
  return stat;
}

var currentCoolantMode = COOLANT_OFF;
var currentCoolantTurret = 1;
var coolantOff = undefined;
var isOptionalCoolant = false;
var forceCoolant = false;

function setCoolant(coolant, turret) {
  var coolantCodes = getCoolantCodes(coolant, turret);
  if (Array.isArray(coolantCodes)) {
    if (singleLineCoolant) {
      skipBlock = isOptionalCoolant;
      outputCoolant = (coolantCodes.join(getWordSeparator()));
    } else {
      for (var c in coolantCodes) {
        skipBlock = isOptionalCoolant;
        outputCoolant = (coolantCodes[c]);
      }
    }
    return undefined;
  }
  return coolantCodes;
}

function getCoolantCodes(coolant, turret) {
  turret = gotMultiTurret ? (turret == undefined ? 1 : turret) : 1;
  isOptionalCoolant = false;
  var multipleCoolantBlocks = new Array(); // create a formatted array to be passed into the outputted line
  if (!coolants) {
    error(localize("Coolants have not been defined."));
  }
  if (tool.type == TOOL_PROBE) { // avoid coolant output for probing
    coolant = COOLANT_OFF;
  }
  if (coolant == currentCoolantMode && turret == currentCoolantTurret) {
    if ((typeof operationNeedsSafeStart != "undefined" && operationNeedsSafeStart) && coolant != COOLANT_OFF) {
      isOptionalCoolant = true;
    } else if (!forceCoolant || coolant == COOLANT_OFF) {
      return undefined; // coolant is already active
    }
  }
  if ((coolant != COOLANT_OFF) && (currentCoolantMode != COOLANT_OFF) && (coolantOff != undefined) && !forceCoolant && !isOptionalCoolant) {
    if (Array.isArray(coolantOff)) {
      for (var i in coolantOff) {
        multipleCoolantBlocks.push(coolantOff[i]);
      }
    } else {
      multipleCoolantBlocks.push(coolantOff);
    }
  }
  forceCoolant = false;

  var m;
  var coolantCodes = {};
  for (var c in coolants) { // find required coolant codes into the coolants array
    if (coolants[c].id == coolant) {
      var localCoolant = parseCoolant(coolants[c], turret);
      localCoolant = typeof localCoolant == "undefined" ? coolants[c] : localCoolant;
      coolantCodes.on = localCoolant.on;
      if (localCoolant.off != undefined) {
        coolantCodes.off = localCoolant.off;
        break;
      } else {
        for (var i in coolants) {
          if (coolants[i].id == COOLANT_OFF) {
            coolantCodes.off = localCoolant.off;
            break;
          }
        }
      }
    }
  }
  if (coolant == COOLANT_OFF) {
    m = !coolantOff ? coolantCodes.off : coolantOff; // use the default coolant off command when an 'off' value is not specified
  } else {
    coolantOff = coolantCodes.off;
    m = coolantCodes.on;
  }

  if (!m) {
    onUnsupportedCoolant(coolant);
    m = 9;
  } else {
    if (Array.isArray(m)) {
      for (var i in m) {
        multipleCoolantBlocks.push(m[i]);
      }
    } else {
      multipleCoolantBlocks.push(m);
    }
    currentCoolantMode = coolant;
    currentCoolantTurret = turret;
    for (var i in multipleCoolantBlocks) {
      if (typeof multipleCoolantBlocks[i] == "number") {
        multipleCoolantBlocks[i] = mFormat.format(multipleCoolantBlocks[i]);
      }
    }
    return multipleCoolantBlocks; // return the single formatted coolant value
  }
  return undefined;
}

function parseCoolant(coolant, turret) {
  var localCoolant;
  if (getSpindle(TOOL) == SPINDLE_MAIN) {
    localCoolant = turret == 1 ? coolant.spindle1t1 : coolant.spindle1t2;
    localCoolant = typeof localCoolant == "undefined" ? coolant.spindle1 : localCoolant;
  } else if (getSpindle(TOOL) == SPINDLE_LIVE) {
    localCoolant = turret == 1 ? coolant.spindleLivet1 : coolant.spindleLivet2;
    localCoolant = typeof localCoolant == "undefined" ? coolant.spindleLive : localCoolant;
  } else {
    localCoolant = turret == 1 ? coolant.spindle2t1 : coolant.spindle2t2;
    localCoolant = typeof localCoolant == "undefined" ? coolant.spindle2 : localCoolant;
  }
  localCoolant = typeof localCoolant == "undefined" ? (turret == 1 ? coolant.turret1 : coolant.turret2) : localCoolant;
  localCoolant = typeof localCoolant == "undefined" ? coolant : localCoolant;
  return localCoolant;
}

function isSpindleSpeedDifferent() {
  var areDifferent = false;
  if (isFirstSection()) {
    areDifferent = true;
  }
  if (lastSpindleDirection != tool.clockwise) {
    areDifferent = true;
  }
  if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
    var _spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0);
    if ((lastSpindleMode != SPINDLE_CONSTANT_SURFACE_SPEED) ||
      rpmFormat.areDifferent(lastSpindleSpeed, _spindleSpeed)) {
      areDifferent = true;
    }
  } else {
    if ((lastSpindleMode != SPINDLE_CONSTANT_SPINDLE_SPEED) ||
      rpmFormat.areDifferent(lastSpindleSpeed, spindleSpeed)) {
      areDifferent = true;
    }
  }
  return areDifferent;
}

function onSpindleSpeed(spindleSpeed) {
  if (rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent())) {
    writeBlock(sOutput.format(spindleSpeed));
  }
}

function startSpindle(tappingMode, forceRPMMode, initialPosition, outputTool) {
  var spindleDir;
  var _spindleSpeed;
  var spindleMode;
  gSpindleModeModal.reset();

  if ((getSpindle(PART) == SPINDLE_SUB) && !gotSecondarySpindle) {
    error(localize("Secondary spindle is not available."));
    return;
  }

  // spindle block cannot be output when spindles are synchronized
  var clampSpindles = false;
  if (machineState.spindlesAreSynchronized || machineState.spindlesAreAttached) {
    // Turning
    if (machineState.isTurningOperation) {
      if (syncStartMethod == SYNC_ERROR) {
        if (isSpindleSpeedDifferent()) {
          error(localize("A spindle start block cannot be output while the spindles are synchronized."));
          return;
        } else {
          return;
        }
      } else if (syncStartMethod == SYNC_UNCLAMP) {
        writeBlock(mFormat.format(getCode("INTERLOCK_BYPASS", getSecondarySpindle())));
        clampChuck(getSecondarySpindle(), UNCLAMP);
        onDwell(1.0);
        clampSpindles = true;
        machineState.spindlesAreAttached = true; // must set so synchronized spindle code is used
      }
    }
  }

  if (tappingMode) {
    spindleDir = mFormat.format(getCode("RIGID_TAPPING", getSpindle(TOOL)));
    /*} else if (machineState.spindlesAreAttached && getSpindle(TOOL) != SPINDLE_LIVE) {
      var method = ((machineState.spindlesAreSynchronized || machineState.spindlesAreAttached) && (syncStartMethod == SYNC_SPEED)) ? TRANSFER_SPEED : transferType;
      var code = (method == TRANSFER_PHASE) ? getCode("SPINDLE_SYNCHRONIZATION_PHASE", getSpindle(PART)) : getCode("SPINDLE_SYNCHRONIZATION_SPEED", getSpindle(PART));
      spindleDir = mFormat.format(tool.clockwise ? code : (code + 1));
    }*/
  } else {
    spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(TOOL)) : getCode("START_SPINDLE_CCW", getSpindle(TOOL)));
  }
  if (getSpindle(PART) == SPINDLE_MAIN) {
  var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.miyano_maximumSpindleSpeed) : properties.miyano_maximumSpindleSpeed;
  } else {
    var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.miyano_maximumSpindleSpeed2) : properties.miyano_maximumSpindleSpeed2;
  }
  if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
    _spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0);
    if (forceRPMMode) { // RPM mode is forced until move to initial position
      if (xFormat.getResultingValue(initialPosition.x) == 0) {
        _spindleSpeed = maximumSpindleSpeed;
      } else {
        _spindleSpeed = Math.min((_spindleSpeed * ((unit == MM) ? 1000.0 : 12.0) / (Math.PI * Math.abs(initialPosition.x * 2))), maximumSpindleSpeed);
      }
      spindleMode = getCode("CONSTANT_SURFACE_SPEED_OFF", getSpindle(TOOL));
    } else {
      spindleMode = getCode("CONSTANT_SURFACE_SPEED_ON", getSpindle(TOOL));
    }
  } else {
    _spindleSpeed = spindleSpeed;
    spindleMode = getCode("CONSTANT_SURFACE_SPEED_OFF", getSpindle(TOOL));
  }

  var toolOffsetFactor = getToolOffsetFactor(tool);
  toolFormat.setMinDigitsLeft(toolOffsetFactor == 1000 ? 5 : 4);
  var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;

  writeBlock(gMotionModal.format(0),"T" + toolFormat.format(tool.number * toolOffsetFactor + compensationOffset % toolOffsetFactor), zOutput.format(initialPosition.z));

  /*
  if (machineState.isTurningOperation) {
    writeBlock(
      mFormat.format(getCode((tool.clockwise ? "START_SPINDLE_CW" : "START_SPINDLE_CCW"), getSpindle(TOOL))),
      "S" + getSpindleCode(currentSection) + "=" + rpmFormat.format(_spindleSpeed), (outputTool ? "T" + toolFormat.format(tool.number * toolOffsetFactor + compensationOffset % toolOffsetFactor) : "")
    );
  } else {
    if (getSpindle(PART) == SPINDLE_MAIN) {
      writeBlock(mFormat.format((tool.number <= 12 ? 43 : 143)),
        "S" + getSpindleCode(currentSection) + "=" + rpmFormat.format(_spindleSpeed), (outputTool ? "T" + toolFormat.format(tool.number * toolOffsetFactor + compensationOffset % toolOffsetFactor) : "")
      );
    } else {
      writeBlock(mFormat.format((tool.number <= 12 ? 44 : 144)),
        "S" + getSpindleCode(currentSection) + "=" + rpmFormat.format(_spindleSpeed), (outputTool ? "T" + toolFormat.format(tool.number * toolOffsetFactor + compensationOffset % toolOffsetFactor) : "")
      );
    }

  }*/
  if (!machineState.isTurningOperation) {
    if (getSpindle(PART) == SPINDLE_MAIN) {
      writeBlock(mFormat.format(5));
    } else {
      writeBlock(mFormat.format(105));
    }
  }
  writeBlock(gSpindleModeModal.format(spindleMode),
    sOutput.format(_spindleSpeed),
    spindleDir,
    spOutput.format(getCode("SELECT_SPINDLE", getSpindle(TOOL)))
  );

  // wait for spindle here if required

  // clamp secondary chuck if necessary
  if (clampSpindles) {
    if (machineState.liveToolIsActive) {
      writeBlock(mFormat.format(getCode("CONNECT_C_AXES", SPINDLE_MAIN)), formatComment("SYNCHRONIZE C1 C2"));
    }
    clampChuck(getSecondarySpindle(), CLAMP);
    onDwell(1.0);
  }

  lastSpindleMode = tool.getSpindleMode();
  lastSpindleSpeed = _spindleSpeed;
  lastSpindleDirection = tool.clockwise;
}

function stopSpindle() {
  const codes = getCode("STOP_SPINDLE", activeSpindle);
  if (Array.isArray(codes)) {
    const line = (Array.isArray(codes) ? codes : [codes]).map((code) => mFormat.format(code)).join(" ");
    writeBlock(line);
  } else {
    if (machineState.isTurningOperation) {
      writeComment(mFormat.format(codes));
    } else {
      writeComment(mFormat.format(codes));
    }
  }
  lastSpindleSpeed = 0;
  lastSpindleDirection = undefined;
  sOutput.reset();
}

/** Positions the sub spindle */
function moveSubSpindle(_method, _position, _feed, _useMachineFrame, _comment, _error) {
  if (!gotSecondarySpindle) {
    return;
  }
  if (machineState.spindlesAreAttached) {
    if (_error) {
      error(localize("An attempt was made to position the sub-spindle with both chucks clamped."));
    }
    return;
  }
  switch (_method) {
  case HOME:
    /*if ((getProperty("useTailStock") == "false") || !machineState.tailstockIsActive) { // don't retract B-axis if used as a tailstock
        writeBlock(
          gMotionModal.format(0),
          gFormat.format(28),
          gFormat.format(53),
          subOutput.format(0),
          conditional(_comment, formatComment(_comment))
        );
      }*/
    break;
  case RAPID:
    writeBlock(
      gMotionModal.format(0),
      conditional(_useMachineFrame, gFormat.format(53)),
      subOutput.format(_position),
      conditional(_comment, formatComment(_comment))
    );
    break;
  case FEED:
    var g53Code;
    if (_useMachineFrame) {
      /*switch (getProperty("useG53ForXfer")) {
        case "g53":
          writeBlock(gFormat.format(53), subOutput.format(_position));
          break;
        case "g532":
          writeBlock(gMotionModal.format(1), gFormat.format(53.2), subOutput.format(_position), getFeed(_feed), conditional(_comment, formatComment(_comment)));
          break;
        case "linear":
          writeBlock(gMotionModal.format(1), subOutput.format(_position), getFeed(_feed), conditional(_comment, formatComment(_comment)));
          break;
        case "error":
          error(localize("The sub-spindle cannot be positioned using a feed rate when Machine Position output is used."));
          return;
        }
        if (properties.useG53ForXfer == "error") {
          error(localize("The sub-spindle cannot be positioned using a feed rate when Machine Position output is used."));
          return;
        }*/
    } else {
      writeBlock(gMotionModal.format(1), subOutput.format(_position), getFeed(_feed), conditional(_comment, formatComment(_comment)));
    }
    break;
  case TORQUE:
    gFeedModeModal.reset();
    gMotionModal.reset();
    writeBlock(
      gFeedModeModal.format(getCode("FEED_MODE_UNIT_MIN", getSpindle(TOOL))),
      gMotionModal.format(1),
      gFormat.format(31),
      pOutput.format(99),
      conditional(_useMachineFrame == 1, gFormat.format(53)),
      subOutput.format(_position),
      getFeed(_feed),
      conditional(_comment, formatComment(_comment))
    );
    break;
  }
}

function clampChuck(_spindle, _clamp) {
  if (_spindle == SPINDLE_MAIN) {
    if (_clamp != machineState.mainChuckIsClamped) {
      writeBlock(mFormat.format(getCode(_clamp ? "CLAMP_CHUCK" : "UNCLAMP_CHUCK", _spindle)),
        formatComment(_clamp ? "CLAMP MAIN CHUCK" : "UNCLAMP MAIN CHUCK"));
      machineState.mainChuckIsClamped = _clamp;
    }
  } else {
    if (_clamp != machineState.subChuckIsClamped) {
      writeBlock(mFormat.format(getCode(_clamp ? "CLAMP_CHUCK" : "UNCLAMP_CHUCK", _spindle)),
        formatComment(_clamp ? "CLAMP SUB CHUCK" : "UNCLAMP SUB CHUCK"));
      machineState.subChuckIsClamped = _clamp;
    }
  }
  machineState.spindlesAreAttached = machineState.mainChuckIsClamped && machineState.subChuckIsClamped;
}

function unwindCAxis() {
  writeBlock(gMotionModal.format(0), gFormat.format(28), "H" + abcFormat.format(0));
}

function onCommand(command) {
  switch (command) {
  case COMMAND_COOLANT_OFF:
    setCoolant(COOLANT_OFF);
    break;
  case COMMAND_COOLANT_ON:
    setCoolant(tool.coolant);
    break;
  case COMMAND_LOCK_MULTI_AXIS:
    writeBlock(cAxisBrakeModal.format(getCode("LOCK_MULTI_AXIS", getSpindle(PART))));
    break;
  case COMMAND_UNLOCK_MULTI_AXIS:
    var unlockCode = cAxisBrakeModal.format(getCode("UNLOCK_MULTI_AXIS", getSpindle(PART)));
    if (unlockCode) {
      writeBlock(cAxisEngageModal.format(getCode("ENABLE_C_AXIS", getSpindle(PART)))); // C-axis must be enabled prior to unlocking it
      writeBlock(unlockCode);
    }
    break;
  case COMMAND_START_CHIP_TRANSPORT:
    writeBlock(mFormat.format(24));
    break;
  case COMMAND_STOP_CHIP_TRANSPORT:
    writeBlock(mFormat.format(25));
    break;
  case COMMAND_OPEN_DOOR:
    if (gotDoorControl) {
      writeBlock(mFormat.format(52)); // optional
    }
    break;
  case COMMAND_CLOSE_DOOR:
    if (gotDoorControl) {
      writeBlock(mFormat.format(53)); // optional
    }
    break;
  case COMMAND_BREAK_CONTROL:
    break;
  case COMMAND_TOOL_MEASURE:
    break;
  case COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION:
    break;
  case COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION:
    break;
  case COMMAND_STOP:
    writeBlock(mFormat.format(0));
    forceSpindleSpeed = true;
    forceCoolant = true;
    break;
  case COMMAND_OPTIONAL_STOP:
    writeBlock(mFormat.format(1));
    forceSpindleSpeed = true;
    forceCoolant = true;
    break;
  case COMMAND_END:
    writeBlock(mFormat.format(2));
    break;
  case COMMAND_STOP_SPINDLE:
    stopSpindle();
    break;
  case COMMAND_ORIENTATE_SPINDLE:
    if (machineState.isTurningOperation || machineState.axialCenterDrilling) {
      writeBlock(mFormat.format(getCode("ORIENT_SPINDLE", getSpindle(PART))));
    } else {
      error(localize("Spindle orientation is not supported for live tooling."));
      return;
    }
    break;
  case COMMAND_SPINDLE_CLOCKWISE:
    writeBlock(mFormat.format(getCode("START_SPINDLE_CW", getSpindle(TOOL))),
      spOutput.format(getCode("SELECT_SPINDLE", getSpindle(TOOL)))
    );
    break;
  case COMMAND_SPINDLE_COUNTERCLOCKWISE:
    writeBlock(mFormat.format(getCode("START_SPINDLE_CCW", getSpindle(TOOL))),
      spOutput.format(getCode("SELECT_SPINDLE", getSpindle(TOOL)))
    );
    break;
    // case COMMAND_CLAMP: // add support for clamping
    // case COMMAND_UNCLAMP: // add support for clamping
  default:
    onUnsupportedCommand(command);
  }
}

/**
 Buffer Manual NC commands for processing later
*/
var bufferPassThrough = false; // enable to output the Pass Through commands until after ending the previous section
var manualNC = [];
function onManualNC(command, value) {
  if (command == COMMAND_PASS_THROUGH && bufferPassThrough) {
    manualNC.push({command:command, value:value});
  } else {
    expandManualNC(command, value);
  }
}

/**
 Processes the Manual NC commands
 Pass the desired command to process or leave argument list blank to process all buffered commands
*/
function executeManualNC(command) {
  for (var i = 0; i < manualNC.length; ++i) {
    if (!command || (command == manualNC[i].command)) {
      expandManualNC(manualNC[i].command, manualNC[i].value);
    }
  }
  for (var i = manualNC.length - 1; i >= 0; --i) {
    if (!command || (command == manualNC[i].command)) {
      manualNC.splice(i, 1);
    }
  }
}

/** Get synchronization/transfer code based on part cutoff spindle direction. */
/*function getSpindleTransferCodes(_transferType) {
  var transferCodes = {direction:0, spindleMode:0, surfaceSpeed:0, maximumSpindleSpeed:0};
  if (_transferType == TRANSFER_PHASE) {
    transferCodes.direction = getCode("SPINDLE_SYNCHRONIZATION_PHASE", getSecondarySpindle());
  } else {
    transferCodes.direction = getCode("SPINDLE_SYNCHRONIZATION_SPEED", getSecondarySpindle());
  }
  transferCodes.spindleDirection = true; // clockwise
  if (isLastSection()) {
    return transferCodes;
  }
  var numberOfSections = getNumberOfSections();
  for (var i = getNextSection().getId(); i < numberOfSections; ++i) {
    var section = getSection(i);
    if (section.getParameter("operation-strategy") == "turningSecondarySpindleReturn" || section.getParameter("operation-strategy") == "turningSecondarySpindlePull") {
      continue;
    } else if (section.getType() != TYPE_TURNING || section.spindle != SPINDLE_PRIMARY) {
      break;
    } else if (section.getType() == TYPE_TURNING) {
      var tool = section.getTool();
      if (!tool.clockwise) {
        transferCodes.direction += 1;
      }
      transferCodes.spindleMode = tool.getSpindleMode();
      transferCodes.surfaceSpeed = tool.surfaceSpeed;
      transferCodes.maximumSpindleSpeed = tool.maximumSpindleSpeed;
      transferCodes.spindleDirection = tool.clockwise;
      break;
    }
  }
  return transferCodes;
}*/

function getG17Code() {
  return (machineState.usePolarInterpolation || !gotYAxis) ? 17 : 17;
}

/*function ejectPart() {
  if (machineState.spindlesAreAttached) {
    error(localize("Cannot eject part when spindles are connected."));
  }
  if (machineState.subChuckIsClamped) {
    spindle = SPINDLE_SUB;
  } else {
    spindle = getSpindle(PART);
  }
  writeln("");
  if (getProperty("showSequenceNumbers") == "toolChange") {
    writeCommentSeqno(localize("PART EJECT"));
  } else {
    writeComment(localize("PART EJECT"));
  }
  gMotionModal.reset();
  moveSubSpindle(HOME, 0, 0, true, "SUB SPINDLE RETURN", true);
  goHome(); // Position all axes to home position
  writeBlock(mFormat.format(getCode("UNLOCK_MULTI_AXIS", spindle)));
  if (!getProperty("optimizeCAxisSelect")) {
    cAxisEngageModal.reset();
  }
  writeBlock(
    gFeedModeModal.format(getCode("FEED_MODE_UNIT_MIN", spindle)),
    gFormat.format(53 + currentWorkOffset),
    gPlaneModal.format(getG17Code()),
    cAxisEngageModal.format(getCode("DISABLE_C_AXIS", spindle))
  );
  //if (getProperty("autoEject") == "flush") {
  //  setCoolant(COOLANT_THROUGH_TOOL);
  //}
  gSpindleModeModal.reset();
  writeBlock(
    gSpindleModeModal.format(getCode("CONSTANT_SURFACE_SPEED_OFF", spindle)),
    sOutput.format(50),
    mFormat.format(getCode("START_SPINDLE_CW", spindle)),
    spOutput.format(getCode("SELECT_SPINDLE", spindle))
  );
  writeBlock(mFormat.format(getCode("INTERLOCK_BYPASS", spindle)));
  //if (getProperty("usePartCatcher")) {
 //   engagePartCatcher(true);
  //}
  clampChuck(spindle, UNCLAMP);
  onDwell(1.5);
  if (getProperty("autoEject") != "flush") {
    writeBlock(mFormat.format(getCode("CYCLE_PART_EJECTOR", spindle)));
    onDwell(0.5);
  }

  // clean out chips
  if (airCleanChuck) {
    writeBlock(mFormat.format(getCode("AIR_BLAST_ON", spindle)));
    onDwell(2.5);
    writeBlock(mFormat.format(getCode("AIR_BLAST_OFF", spindle)));
  }
  writeBlock(mFormat.format(getCode("STOP_SPINDLE", spindle)), spOutput.format(getCode("SELECT_SPINDLE", spindle)));
  //if (getProperty("autoEject") == "flush") {
  //  setCoolant(COOLANT_OFF);
  //}
  //if (getProperty("usePartCatcher")) {
  //  onDwell(2); // allow coolant to drain
  //  engagePartCatcher(false);
  //  onDwell(1.1);
  //}
  writeComment(localize("END OF PART EJECT"));
  writeln("");
}*/

/*function engagePartCatcher(engage) {
  if (getProperty("usePartCatcher")) {
    if (engage) { // engage part catcher
      writeBlock(mFormat.format(getCode("PART_CATCHER_ON", true)), formatComment(localize("PART CATCHER ON")));
      if ((getProperty("partCatcherPosition") != 0) &&
          (getSpindle(PART) == SPINDLE_MAIN) &&
          !machineState.spindlesAreAttached &&
          !machineState.tailstockIsActive) {
        moveSubSpindle(RAPID, getProperty("partCatcherPosition"), 0, true, "POSITION PART CATCHER", true);
      }
    } else { // disengage part catcher
      onCommand(COMMAND_COOLANT_OFF);
      if ((getProperty("partCatcherPosition") != 0) &&
          (getSpindle(PART) == SPINDLE_MAIN) &&
          !machineState.spindlesAreAttached &&
          !machineState.tailstockIsActive) {
        moveSubSpindle(HOME, 0, 0, true, "RETRACT PART CATCHER", true);
      }
      writeBlock(mFormat.format(getCode("PART_CATCHER_OFF", true)), formatComment(localize("PART CATCHER OFF")));
    }
  }
}*/

/*function engageTailStock(engage) {
  var _engage = engage;
  if (engage && (currentSection.tailstock || forceTailStock)) {
    if (machineState.axialCenterDrilling || (getSpindle(PART) == SPINDLE_SUB) ||
        (getParameter("operation-strategy") == "turningFace") ||
        ((getSpindle(TOOL) == SPINDLE_LIVE) && (machineState.machiningDirection == MACHINING_DIRECTION_AXIAL))) {
      warning(localize("Tail stock is not supported for secondary spindle or Z-axis milling."));
      _engage = false;
    }
  } else if (!currentSection.tailstock && !forceTailStock) {
    _engage = false;
  }

  if (_engage) {
    if (!machineState.tailstockIsActive) {
      machineState.tailstockIsActive = true;
      if (getProperty("useTailStock") == "true") {
        writeBlock(tailStockModal.format(getCode("TAILSTOCK_ON", SPINDLE_MAIN)));
      } else if (getProperty("useTailStock") == "subSpindle" || getProperty("useTailStock") == "noTorque") {
        if (getSpindle(PART) == SPINDLE_SUB) {
          error(localize("Only the sub spindle can be used as a live center tail stock."));
        }
        var rapidPosition = getProperty("useTailStockPositioning") == "offset" ?  getGlobalParameter("stock-upper-z") + getProperty("useTailStockPosition") : getProperty("useTailStockPosition");
        writeBlock(mInterferModal.format(getCode("INTERFERENCE_CHECK_OFF", getSpindle(PART))));
        gMotionModal.reset();
        moveSubSpindle(RAPID, rapidPosition, 0, getProperty("useTailStockPositioning") == "machine", "", true);
        // writeBlock(mFormat.format(getCode("TORQUE_SKIP_ON", getSpindle(PART))), formatComment("TORQUE SKIP ON"));
        writeBlock(gFormat.format(getCode("TAILSTOCK_CONTROL_ON", SPINDLE_MAIN)), subOutput.format(-getProperty("useTailStockTorque")), formatComment("ENGAGE LIVE CENTER"));
        if (getProperty("useTailStock") == "noTorque") {
          writeBlock(gFormat.format(getCode("TAILSTOCK_CONTROL_OFF", SPINDLE_MAIN)), formatComment("CANCEL TORQUE CONTROL"));
        }
        // writeBlock(mFormat.format(getCode("TORQUE_SKIP_OFF", getSpindle(PART))), formatComment("TORQUE SKIP OFF"));
      }
    }
  } else {
    if (machineState.tailstockIsActive) {
      machineState.tailstockIsActive = false;
      if (getProperty("useTailStock") == "true") {
        writeBlock(tailStockModal.format(getCode("TAILSTOCK_OFF", SPINDLE_MAIN)));
      } else if (getProperty("useTailStock") == "subSpindle") {
        writeBlock(gFormat.format(getCode("TAILSTOCK_CONTROL_OFF", SPINDLE_MAIN)), formatComment("CANCEL TORQUE CONTROL"));
        moveSubSpindle(HOME, rapidPosition, 0, true, "SUB SPINDLE RETURN", true);
      }
    }
  }
}*/

function onSectionEnd() {
  if (!groupedOperations) {
    gMotionModal.reset();
    gPlaneModal.reset();
    gFeedModeModal.reset();
    gSpindleModeModal.reset();
    gSpindleModal.reset();
    gUnitModal.reset();
    gCycleModal.reset();
    gPolarModal.reset();
    cAxisBrakeModal.reset();
    mInterferModal.reset();
    cAxisEngageModal.reset();
    gWCSModal.reset();
    tailStockModal.reset();
    xOutput.reset();
    yOutput.reset();
    zOutput.reset();
    aOutput.reset();
    bOutput.reset();
    cOutput.reset();
    barOutput.reset();
    feedOutput.reset();
    pitchOutput.reset();
    sOutput.reset();
    threadP1Output.reset();
    threadP2Output.reset();
    threadQOutput.reset();
    threadROutput.reset();

    gPlaneModal.reset();
    if (machineState.usePolarInterpolation) {
      setPolarInterpolation(false); // disable polar interpolation mode
    }

    if (isPolarModeActive()) {
      setPolarCoordinates(false); // disable Polar coordinates mode
    }
    var outputTool;
    // cancel SFM mode to preserve spindle speed
    if ((tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) &&
      !machineState.spindlesAreAttached && !machineState.spindlesAreSynchronized &&
      (currentSection.getParameter("operation-strategy") != "turningSecondarySpindleReturn") &&
      currentSection.getParameter("operation-strategy") != "turningSecondarySpindlePull") {
      writeBlock(gFormat.format(97));
     // startSpindle(false, true, getFramePosition(currentSection.getFinalPosition()));
    }

    // if (getProperty("usePartCatcher") && partCutoff && currentSection.partCatcher) {
    // engagePartCatcher(false);
    // }
    // if (getProperty("cutoffConfirmation") != "false" && partCutoff) {
    //   writeBlock(gFormat.format(getProperty("cutoffConfirmation") == "true" ? 350 : 133), formatComment("CONFIRM CUTOFF"));
    //   onDwell(0.5);
    // }
    // if (partCutoff) {
    //   machineState.spindlesAreAttached = false;
    // }

    if (operationSupportsTCP && currentSection.isMultiAxis()) {
      writeBlock(gFormat.format(49)); // disable length compensation
      // writeBlock(gFormat.format(701), formatComment("DISABLE TCP"));
      writeBlock(mFormat.format(getCode("YAXIS_INTERLOCK_RELEASE_OFF")), formatComment("Y-AXIS INTERLOCK RELEASE OFF"));
    }

    //if (((getCurrentSectionId() + 1) >= getNumberOfSections()) && currentSection.isTurningOperation && getNextSection.getType() == TYPE_TURNING) {
    //  onCommand(COMMAND_STOP_SPINDLE);
    // } else if (!machineState.isTurningOperation) {
    if (machineState.isTurningOperation) {
      onCommand(COMMAND_STOP_SPINDLE);
    } else {
      if (getSpindle(PART) == SPINDLE_MAIN) {
        if (isPolarModeActive()) {
          writeBlock(mFormat.format(5), mFormat.format(245));
        } else {
          writeBlock(mFormat.format(245));
        }
      } else {
        if (isPolarModeActive()) {
          writeBlock(mFormat.format(105), mFormat.format(245));
        } else {
          writeBlock(mFormat.format(245));
        }
      }
    }
    // }
    onCommand(COMMAND_COOLANT_OFF);
    setCoolant(tool.coolant);
    if (getSection(0).spindle == SPINDLE_PRIMARY && outputCoolant == "M8") {
      writeBlock("(" + mFormat.format(9) + ")");
    } else {
      writeBlock("(" + mFormat.format(109) + ")");
    }

    goHome();
    forcePolarCoordinates = false;
    forcePolarInterpolation = false;
    partCutoff = false;
    forceAny();
    if (turretNum == 1) {
      writeBlock(mFormat.format(29));
    } else if (turretNum == 2) {
      writeBlock(mFormat.format(129));
    //} else if (turretNum == 3) {
    //  writeBlock(mFormat.format(329));
    }
    if (properties.miyano_optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
      gMotionModal.reset();
      forceSpindle = true;
    }
    machineState.usePolarMode = false;
    forceXZCMode = false;
    forcePolarMode = false;
    partCutoff = false;
    // onCommand(COMMAND_STOP_SPINDLE);

    closedSection = true;
    forceAny();
    shouldRedirect = false;
    tooloffsetOutput = false;
  }
}
function formatElement(text) {
  return "\"" + text + "\"";
}

function createXML() {
  toolRenderer = createToolRenderer();
  if (toolRenderer) {
    toolRenderer.setBackgroundColor(new Color(1, 1, 1));
    toolRenderer.setFluteColor(new Color(40.0 / 255, 40.0 / 255, 40.0 / 255));
    toolRenderer.setShoulderColor(new Color(80.0 / 255, 80.0 / 255, 80.0 / 255));
    toolRenderer.setShaftColor(new Color(80.0 / 255, 80.0 / 255, 80.0 / 255));
    toolRenderer.setHolderColor(new Color(40.0 / 255, 40.0 / 255, 40.0 / 255));
  }
  var path = FileSystem.replaceExtension(getOutputPath(), "xml");
  var file = new TextFile(path, true, "utf-8");
  if (debugMode || !base64encoded) {
    file.write(getXMLJobContent());
  } else {
    file.write(Base64.btoa(getXMLJobContent()));
  }
  file.close();
}

function getXMLJobContent() {
  var workpiece = getWorkpiece();
  var delta = Vector.diff(workpiece.upper, workpiece.lower);
  xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
  const jobContents = {};
  jobContents.Job = {
    Name         : formatText(getGlobalParameter("document-path")),
    Unit         : (unit == MM ? "MM" : "IN"),
    StockLength  : xFormat.format(delta.z),
    StockDiameter: xFormat.format(Math.max(delta.x, delta.y)),
    ModelImage   : FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), (modelImagePath ? modelImagePath : "placeholder.png"))
  };
  jobContents.Job.Files = {File:[]};
  for (var i = 0; i < outputDocuments.length; ++i) {
    let modelImage = outputDocuments[i].image;
    if (modelImage) {
      modelImage = FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), modelImage);
    }
    jobContents.Job.Files.File.push(file = {
      Location     : outputDocuments[i].ncLocation,
      Description  : formatText(outputDocuments[i].name),
      OperationType: outputDocuments[i].type,
      Spindle      : outputDocuments[i].spindle,
      MachiningType: outputDocuments[i].spindleType,
      Setup        : formatText(outputDocuments[i].setupName),
      toolpathImage: modelImage,
      Tool         : {
        Image      : FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), createToolImage(outputDocuments[i].tool, outputDocuments[i].tool.number)),
        Number     : outputDocuments[i].tool.number,
        Description: outputDocuments[i].tool.description != "" ? formatText(outputDocuments[i].tool.description) : "unspecified",
        Turret     : outputDocuments[i].tool.turret
      }
    });
  }
  const builderOptions = {
    format              : true,
    ignoreAttributes    : false,
    attributeNamePrefix : "@",
    suppressEmptyNode   : true,
    alwaysCreateTextNode: false
  };

  const xmlDataStr = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" + json2xml(jobContents, builderOptions);
  warning(xmlDataStr);
  return xmlDataStr;
}

function getSetupName(path) {
  return path.split("\\")[1];
}

var exportedTools = {};
var toolRenderer;
function createToolImage(tool, name) {
  var id = name;
  var relPath = name + ".png";
  var width = 2.5 * 100;
  var height = 2.5 * 133;
  var mimetype = "image/png";
  try {
    if (!exportedTools[id]) {
      toolRenderer.exportAs(relPath, mimetype, tool, width, height);
      exportedTools[id] = true; // do not export twice
    }
  } catch (e) {
    error(e.toString());
  }
  return encodeURIComponent(relPath);
}

function onClose() {

  closeSection();
  if (!debugMode && isRedirecting()) {
    closeRedirection();
    b64Output();
  }
  createXML();
  writeln("Posting from Fusion has been successful.\n");
  writeln("Files have been written to " + String.fromCharCode(39) + FileSystem.getFolderPath(getOutputPath()) + String.fromCharCode(39) + "\n");
  writeln("Please use the Fusion import utility in CNC Wizard to continue");
}

function onTerminate() {
  // enable to create a file with the name Oxxxx when running off of a memory card
  if (false) {
    var path = FileSystem.getFolderPath(getOutputPath());
    var fileName = FileSystem.getFilename(getOutputPath());
    var inc = fileName.indexOf(".");
    var file = fileName.substr(0, inc);

    var newFile = "O" + file;
    FileSystem.copyFile(getOutputPath(), FileSystem.getCombinedPath(path, newFile));
  }
}
