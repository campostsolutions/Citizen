/// <reference path="c:\Users\millara\.vscode\extensions\autodesk.hsm-post-processor-4.1.7\res\language files\globals.d.ts" />
/**
  Copyright (C) 2012-2018 by Autodesk, Inc.
  All rights reserved.

  Citizen post processor configuration.
  $Revision$
  $Date$

  FORKID {C7A4BD6C-CF7A-4299-BF94-3C18351E8FA7}
*/
var gFormat = createFormat({prefix:"G", decimals:0});
var g1Format = createFormat({prefix:"G", decimals:1, forceDecimal:false});
var mFormat = createFormat({prefix:"M", decimals:0});

generalSettings = {};

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
//override this in each post with what's needed

function selectEncoder(encoder) {
  if (getSpindle(true) == SPINDLE_MAIN) {
    writeBlock(gFormat.format(43));
  } else {
    writeBlock(gFormat.format(44));
  }
}

function getSpindleAxis() {
  if (getSpindle(false) != SPINDLE_LIVE) {
    return POSX;
  }
  if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
    return POSZ;
  } else if (isPerpto(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
    return POSX;
  } else {
    return 17;
  }
}

var currentFeedMode = undefined;

function safeStartSection(tempSpindle, newSpindle, abcValue) {
  formatSubProgramNumber();

  if (generalSettings.toolpost == "oppositeEndWorking1" || generalSettings.toolpost == "oppositeEndWorking2") {
    if (!redirectStarted) {
      writeBlock(formatComment("G610 MODE ONLY"));
    }
  }
  var plane = 18;
  // End the previous section if a new tool is selected
  writeBlock(gFormat.format(40), gFormat.format(80), gFormat.format(plane) /*(machineState.usePolarMode ? gPlaneModal.format(17) : gPlaneModal.format(plane))*/, (tempSpindle == SPINDLE_LIVE ? gFeedModeModal.format(getCode("FEED_MODE_MM_MIN")) : gFeedModeModal.format(getCode("FEED_MODE_MM_REV"))));
  currentFeedMode = (tempSpindle == SPINDLE_LIVE ? 0 : 1);

  if (!partCutoff) {
    mInterferModal.reset();
    if (properties.optionalStop) {
      // onCommand(COMMAND_OPTIONAL_STOP);
      gMotionModal.reset();
    }
    debugSectionHeader("onToolChange");
    onToolChange(tempSpindle, abcValue);
  }

  // Cancel the reverse spindle code used in tapping
  if (reverseTap) {
    writeBlock(mFormat.format(177));
    reverseTap = false;
  }
}

function getCode(code, spindle) {
  switch (code) {
  case "ENABLE_C_AXIS":
    machineState.cAxisIsEngaged = true;
    return (spindle == SPINDLE_MAIN) ? 35 : 135;
  case "POLAR_INTERPOLATION_ON":
    return 12.1;
  case "POLAR_INTERPOLATION_OFF":
    return 13.1;
  case "STOP_SPINDLE":
    if (generalSettings.spindleOff.live) {
      if (getSpindle(false) == SPINDLE_LIVE) {
        return generalSettings.spindleOff.live;
      } else {
        return generalSettings.spindleOff.static;
      }
    } else {
      return generalSettings.spindleOff;
    }
  case "ORIENT_SPINDLE":
    return (spindle == SPINDLE_MAIN) ? 19 : 119;
  case "START_SPINDLE_CW":
    if (generalSettings.spindleOnCW.live) {
      if (getSpindle(false) == SPINDLE_LIVE) {
        return generalSettings.spindleOnCW.live;
      } else {
        return generalSettings.spindleOnCW.static;
      }
    } else {
      return generalSettings.spindleOnCW;
    }
  case "START_SPINDLE_CCW":
    if (generalSettings.spindleOnCCW.live) {
      if (getSpindle(false) == SPINDLE_LIVE) {
        return generalSettings.spindleOnCCW.live;
      } else {
        return generalSettings.spindleOnCCW.static;
      }
    } else {
      return generalSettings.spindleOnCCW;
    }
  case "FEED_MODE_MM_REV":
    return 99;
  case "FEED_MODE_MM_MIN":
    return 98;
  case "CONSTANT_SURFACE_SPEED_ON":
    return 96;
  case "CONSTANT_SURFACE_SPEED_OFF":
    return 97;
  case "LOCK_MULTI_AXIS":
    return (spindle == SPINDLE_MAIN) ? 89 : 189;
  case "UNLOCK_MULTI_AXIS":
    return (spindle == SPINDLE_MAIN) ? 90 : 190;
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
      return 12;
    case SPINDLE_SUB:
      machineState.mainSpindleIsActive = false;
      machineState.subSpindleIsActive = true;
      machineState.liveToolIsActive = false;
      return 13;
    }
    break;
  case "RIGID_TAPPING":
    return 29;
  case "INTERFERENCE_CHECK_OFF":
    return 110;
  case "INTERFERENCE_CHECK_ON":
    return 111;
  }
  return error("Undefined command");
}

xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});

// override this in each post to define what scaling to use
function setScaling(toolNumber) {
  xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.xScale ? generalSettings.xScale : 1});
  yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.yScale ? generalSettings.yScale : 1});
  zFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.zScale ? generalSettings.zScale : 1});
  iOutput = createReferenceVariable({prefix:"I", force:true}, xFormat);
  jOutput = createReferenceVariable({prefix:"J", force:true}, yFormat);
  kOutput = createReferenceVariable({prefix:"K", force:true}, zFormat);
  xOutput = createVariable({prefix:"X"}, xFormat);
  zOutput = createVariable({prefix:"Z"}, zFormat);
  wOutput = createVariable({prefix:"W"}, zFormat);
  yOutput = createVariable({prefix:"Y"}, yFormat);
  cFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
  if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
    crossWorking = true;
  } else {
    crossWorking = false;
  }
  //let crossWorking = (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL);
  var offset90 = ((toolNumber >= 11 && toolNumber <= 14) && (!description.includes("M5")) || (toolNumber >= 21 && toolNumber <= 23) && !offset180);
  var offset180 = ((toolNumber >= 21 && toolNumber <= 23) && crossWorking) || (description.includes("M5") && (tool.number >= 20 && tool.number <= 29));
  var offset270 = (toolNumber >= 11 && toolNumber <= 14) && (description.includes("M5"));
  cFormat.setOffset(offset90 ? 90 : offset180 ? 180 : offset270 ? 270 : 0);
  eFormat.setOffset(offset90 ? 90 : offset180 ? 180 : offset270 ? 270 : 0);
  cOutput = createOutputVariable({prefix:"C"}, cFormat);
  cOutput.setCyclicLimit(360);
  eOutput = createOutputVariable({prefix:"E"}, eFormat);
  eOutput.setCyclicLimit(360);

  //added here for baxis polar
  if (currentSection.isMultiAxis() && generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual") {

    xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.xScale ? generalSettings.xScale : 1});
    yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.yScale ? generalSettings.yScale : 1});
    zFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.zScale ? generalSettings.zScale : 1});
    if (generalSettings.toolpost == "gangBaxisManual" || currentSection.isMultiAxis()) {
      xOutput = createVariable({prefix:"X"}, xFormat);
      yOutput = createVariable({prefix:"Y"}, yFormat);
      zOutput = createVariable({prefix:"Z"}, zFormat);
    } else {
      xOutput = createVariable({prefix:"Z"}, xFormat);
      yOutput = createVariable({prefix:"Y"}, yFormat);
      zOutput = createVariable({prefix:"X"}, zFormat);
    }
    yPolarFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:1});
  }
  if (generalSettings.toolpost == "backToolPostStatic" || generalSettings.toolpost == "oppositeEndWorking1") {
    yPolarFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-1});
  }
  if (machineState.usePolarMode) {
    yOutput = createVariable({prefix:"Y"}, yPolarFormat);
    cOutput.disable();
  } else if (!gotYAxis) {
    yOutput = createVariable({prefix:"Y"}, yFormat);
    yOutput.disable();
  }
}
// common output of WCS
function setWCS(tempSpindle, feedMode) {
  // Live Spindle is active
  if (tempSpindle == SPINDLE_LIVE) {
    forceUnlockMultiAxis();
    var plane = getMachiningDirection(currentSection) == MACHINING_DIRECTION_AXIAL ? getG17Code() : 18;
    gPlaneModal.reset();
    if (optimizeCaxisSelect) {
      cAxisEngageModal.reset();
    }
    writeBlock(wcsOut);
    writeBlock(feedMode, gPlaneModal.format(plane), cAxisEngageModal.format(getCode("ENABLE_C_AXIS", getSpindle(true))));
    writeBlock(gMotionModal.format(0), gFormat.format(28), "H" + abcFormat.format(0)); // unwind c-axis
    if (!machineState.usePolarMode && !machineState.useXZCMode && !currentSection.isMultiAxis()) {
      onCommand(COMMAND_LOCK_MULTI_AXIS);
    }

    // Turning is active
  } else {
    forceUnlockMultiAxis();
    gPlaneModal.reset();
    if (optimizeCaxisSelect) {
      cAxisEngageModal.reset();
    }
    writeBlock(wcsOut);
    if ((tool.maximumSpindleSpeed > 0) && (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
      var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
      writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
      sOutput.reset();
    }
  }
}

function getEncoder() {
  if (generalSettings.encoder.live) {
    return getSpindle(false) == SPINDLE_LIVE ? generalSettings.encoder.live : generalSettings.encoder.static;
  } else {
    return generalSettings.encoder;
  }
}

// tool change formatting
function onToolChange(tempSpindle, abcValue) {
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  forceWorkPlane();
  retracted = true;
  if (debugMode) {
    writeln(generalSettings.toolpost);
  }
  // ADDED HERE TO FORCE POLAR ON IF NOT DRILLING ON THE FACE WITH OPPENDWORKING AND BACKTOOLPOST (<1mm TRAVEL IN Y ON *SOME* MACHINES)
  if (generalSettings.toolpost == "oppositeEndWorking1" || generalSettings.toolpost == "backToolPostStatic") {
    if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1)) && (!currentSection.isMultiAxis())) {
      if (currentSection.getType() == TYPE_MILLING) {
        if ((getParameter("operation-strategy") != "drill")) {
          machineState.usePolarMode = true;
        } else {
          machineState.useXZCMode = true;
        }
      }
    }
  }
  if (getSpindle(true) != SPINDLE_MAIN) {
    if (properties.subSpindlePhaseAngle != 0) {
      cFormat.setOffset(properties.subSpindlePhaseAngle);
    }
  }
  var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
  gMotionModal.reset();
  if (generalSettings.prepositionOnToolChange) {
    if (generalSettings.safetyVal) {
      if (generalSettings.toolpost == "gangBaxisDriven") {
        writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + xFormat.format(tool.diameter + 1));
      } else {
        if (!currentSection.getParameter("operation:isRotaryStrategy") && generalSettings.toolpost != "gangEndWorking") {
          writeBlock(gMotionModal.format(0), generalSettings.safetyVal);
        }
      }
      gMotionModal.reset();
    }
  }
  if (tempSpindle == SPINDLE_LIVE) {
    if (generalSettings.toolpost == "oppositeEndWorking1" || (generalSettings.toolpost == "oppositeEndWorking2")) {
      writeBlock("S1=0");
      writeBlock(
        gFormat.format(97), spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(false)) : getCode("START_SPINDLE_CCW", getSpindle(false)))
        + "S" + getEncoder() + "=" + rpmOutput.format(tool.spindleRPM)
        + "T" + tool.number * 100
      );
    } else {
      if (getSpindle(true) != SPINDLE_MAIN) {
        if (properties.subSpindlePhaseAngle != 0) {
          eFormat.setOffset(properties.subSpindlePhaseAngle);
        }
      }
      var evalue = eOutput.format(Math.abs(abcValue.z));
      if (!currentSection.isMultiAxis()) {
        writeBlock(
          gFormat.format(97), spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(false)) : getCode("START_SPINDLE_CCW", getSpindle(false)))
          + "S" + getEncoder() + "=" + rpmOutput.format(tool.spindleRPM)
          + "T" + tool.number * 100
          + evalue
        );
      } else {
        writeBlock(
          gFormat.format(97), spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(false)) : getCode("START_SPINDLE_CCW", getSpindle(false)))
          + "S" + getEncoder() + "=" + rpmOutput.format(tool.spindleRPM)
          + "T" + tool.number * 100
          + "E0"
        );
      }
    }
  } else {

    if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      var iniX = Math.abs(initialPosition.x);
      var firstSpeed = tool.surfaceSpeed / Math.PI / (iniX * 2);
      var firstSpeed = Math.min(firstSpeed, properties.maximumSpindleSpeed);
      CSSFormat = rpmFormat.format(firstSpeed);
    }

    if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      //    CSSFormat =(_spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0))
    }

    if (!machineState.axialCenterDrilling) {
      writeBlock(
        gFormat.format(97), spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(false)) : getCode("START_SPINDLE_CCW", getSpindle(false)))
        + "S" + getEncoder() + "=" + (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED ? CSSFormat : spindleSpeed)
        + "T" + tool.number * 100
      );
    } else {
      writeBlock(
        gFormat.format(97), spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(false)) : getCode("START_SPINDLE_CCW", getSpindle(false)))
        + "S" + getEncoder() + "=" + +rpmOutput.format(tool.spindleRPM)
        + "T" + tool.number * 100
      );
    }
  }

  selectEncoder(getEncoder());

  gMotionModal.reset();

  if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
    if (generalSettings.fluctuation && generalSettings.fluctuation.off) {
      writeBlock(generalSettings.fluctuation.off);
    }
  }
  if (properties.highPressureCoolantCode != "") {
    writeBlock(properties.highPressureCoolantCode + " (HPC ON)");
  }
  //---------------
  // command stop for manual tool change, useful for quick change live tools
  if (tool.manualToolChange) {
    onCommand(COMMAND_STOP);
    writeBlock("(" + "MANUAL TOOL CHANGE TO T" + toolFormat.format(tool.number * 100 + compensationOffset) + ")");
  }
}

/** Refine segment for XC mapping. */
function refineSegmentXC(startX, startC, endX, endC, maximumDistance) {
  var rotary = machineConfiguration.getAxisU(); // C-axis
  var startPt = rotary.getAxisRotation(startC).multiply(new Vector(startX, 0, 0));
  var endPt = rotary.getAxisRotation(endC).multiply(new Vector(endX, 0, 0));

  var testX = startX + (endX - startX) / 2; // interpolate as the machine
  var testC = startC + (endC - startC) / 2;
  var testPt = rotary.getAxisRotation(testC).multiply(new Vector(testX, 0, 0));

  var delta = Vector.diff(endPt, startPt);
  var distf = pointLineDistance(startPt, endPt, testPt);

  if (distf > maximumDistance) {
    return false; // out of tolerance
  } else {
    return true;
  }
}

function initialPositioning(abc) {
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  gMotionModal.reset();
  var toolOut = false;
  if (properties.useG50OnGang && generalSettings.g50Offset) {
    writeBlock(gFormat.format(50), wOutput.format(generalSettings.g50Offset));
  }
  if (tool.number >= 31 && tool.number <= 39) {
    if (isFirstSection) {
      if (currentSection.getType() == TYPE_MILLING) {
        if (generalSettings.toolpost == "backToolPostStatic") {
          if (!getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
            if (!currentSection.isMultiAxis()) {
              writeBlock(gMotionModal.format(0), machineState.usePolarMode ? xOutput.format(getModulus(initialPosition.x, initialPosition.y)) : xOutput.format(initialPosition.x), generalSettings.safetyVal + "T" + tool.number);
            } else {
              writeBlock(gMotionModal.format(0), xOutput.format(getModulus(initialPosition.x, initialPosition.y)), zOutput.format((-1 - tool.diameter / 2) * -1) + "T" + tool.number);
            }
          } else {
            writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), zOutput.format((-1 - tool.diameter / 2) * -1) + "T" + tool.number);
          }
        } else {
          writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), zOutput.format((-1 - tool.diameter / 2) * -1) + "T" + tool.number);
        }
      } else {
        writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), generalSettings.safetyVal + "T" + tool.number);
        if ((tool.maximumSpindleSpeed > 0) && (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
          var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
          writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
          writeBlock(gFormat.format(96), sOutput.format(_spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0)));
          sOutput.reset();
        }
      }
    } else {
      writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), generalSettings.safetyVal);
    }
    zOutput.reset();
    toolOut = true;
  }
  if (machineState.useXZCMode) {

    if (generalSettings.toolpost == "oppositeEndWorking1") {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z),
        xOutput.format(getModulus(initialPosition.x, initialPosition.y)),
        cOutput.format(getCClosest(initialPosition.x, initialPosition.y, cOutput.getCurrent(), false)) + (!toolOut ? "T" + tool.number : ""));
    } else {
      writeBlock(gMotionModal.format(0), xOutput.format(getModulus(initialPosition.x, initialPosition.y)), zOutput.format(initialPosition.z), cOutput.format(getC(initialPosition.x, initialPosition.y)) + (!toolOut ? "T" + tool.number : ""));
      writeBlock(gMotionModal.format(0),
        xOutput.format(getModulus(initialPosition.x, initialPosition.y)),
        cOutput.format(getC(initialPosition.x, initialPosition.y))
      );
    }
  } else if (gotBAxis && generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual") {
    if (machineState.usePolarMode) {
      writeBlock(gMotionModal.format(0), generalSettings.xScale == 1 ? xOutput.format((getModulus(initialPosition.x, initialPosition.y)) * -1) : xOutput.format((getModulus(initialPosition.x, initialPosition.y))), zOutput.format(initialPosition.z));
    } else {
      if (!generalSettings.newGen) {
        writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), generalSettings.toolpost == "gangBaxisManual" ? "" : zOutput.format(initialPosition.z));
      } else {
        cOutput.reset();
        bOutput.reset();
        writeBlock(gMotionModal.format(1), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), bOutput.format(abc.y), properties.useParametricFeed ? "F#109" : feedOutput.format(highFeedrate));
      }
    }
  } else {
    if (generalSettings.toolpost == "oppositeEndWorking1" || generalSettings.toolpost == "oppositeEndWorking2") {
      if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
        writeBlock(gMotionModal.format(0), xOutput.format(getModulus(initialPosition.x, initialPosition.y)), currentSection.getType() == TYPE_MILLING && !machineState.usePolarMode ? yOutput.format(initialPosition.y) : "", "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + (!toolOut ? "T" + tool.number : ""));
      } else {
        if (currentSection.isMultiAxis()) {
          writeBlock(gMotionModal.format(0), xOutput.format(getModulus(initialPosition.x, initialPosition.y)), currentSection.getType() == TYPE_MILLING && !machineState.usePolarMode ? yOutput.format(initialPosition.y) : "", "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + (!toolOut ? "T" + tool.number : ""));
        } else {
          writeBlock(gMotionModal.format(0), xOutput.format(getModulus(initialPosition.x, initialPosition.y)), currentSection.getType() == TYPE_MILLING && !machineState.usePolarMode ? yOutput.format(initialPosition.y) : "", "Z-1." + (!toolOut ? "T" + tool.number : ""));
        }
      }
      if (machineState.usePolarMode) {
        // writeBlock(gFormat.format(0), "C0"); // set C-axis to 0 to avoid G112 issues
      }
      writeBlock(gFormat.format(0), zOutput.format(initialPosition.z), machineState.usePolarMode ? xOutput.format(getModulus(initialPosition.x, initialPosition.y)) : xOutput.format(initialPosition.x), currentSection.getType() == TYPE_MILLING && !machineState.usePolarMode ? yOutput.format(initialPosition.y) : "");
    } else {
      //if (getParameter("operation-strategy") != "drill") {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z), (!tool.isTurningTool() ? yOutput.format(initialPosition.y) : "") + (!toolOut ? "T" + tool.number : ""));
      if (generalSettings.toolpost == "backToolPostStatic") {
        writeBlock(gMotionModal.format(0), xOutput.format(getModulus(initialPosition.x, initialPosition.y)));
      } else {
        writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x));

      }
      // }
      if (generalSettings.toolpost == "gangTurning") {
        if ((tool.maximumSpindleSpeed > 0) && (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
          var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
          writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
          writeBlock(gFormat.format(96), sOutput.format(_spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0)));
          sOutput.reset();
        }
      }

    }
  }
}

let workplaneActive = false;
function cancelWorkPlane() {
  if (!workplaneActive) {
    return;
  }
  workplaneActive = false;
  debugSectionHeader("cancelWorkPlane");
  cancelTransformation();
  if (gotBAxis) {
    if (bAxisIsManual) {
      writeBlock(gWCSModal.format(69.1));
    } else {
      if (generalSettings.toolpost == "gangBaxisDriven") {
        if (machineState.usePolarMode) {
          if (generalSettings.newGen) {
            writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + xyzFormat.format(tool.diameter * 2 + 1));
            writeBlock(bFormat.format(90 / 180 * Math.PI));
            writeBlock(gFormat.format(50), "W#2");
          } else {
            writeBlock(gMotionModal.format(0), "X-#100450" + "-" + xyzFormat.format(tool.diameter + 1), bFormat.format(90 / 180 * Math.PI));
          }
        } else {
          if (generalSettings.newGen) {
            if (getParameter("operation:isMultiAxisStrategy") == 0) {
              writeBlock("G931");
            } else {
              writeBlock("G921");
            }
            writeBlock(gFormat.format(0), gFormat.format(18), "X#100450+" + xyzFormat.format((tool.diameter * 2 + 1)), yOutput.format(0));
            writeBlock(gFormat.format(910) + "B90.");
          } else {
            writeBlock(gWCSModal.format(951));
            writeBlock(gFormat.format(0), gFormat.format(18), "X#100450+" + xyzFormat.format((tool.diameter + 1)) + "B90.0");
            writeBlock(gWCSModal.format(901));
          }
        }

      } else if (generalSettings.toolpost == "gangBaxisManual") {
        if (!machineState.usePolarMode) {
          writeBlock(gWCSModal.format(951));
        }
      }
    }
  }
}
let tooloffsetOutput = false;
var currentABC = undefined;
function setWorkPlane(abc) {

  debugSectionHeader("setWorkplane");
  workplaneActive = true;

  if (gotBAxis) {
    var initialPosition = currentSection.getInitialPosition();
    var matrixTest = machineConfiguration.getRemainingOrientation(new Vector(0, 0, 1), currentSection.workPlane);
    var transformedPosition = matrixTest.multiply(initialPosition);

    if (generalSettings.toolpost == "gangBaxisManual") {
      var addTo814 = Math.abs(xFormat.format((tool.diameter + 1) * -1));
      writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + xFormat.format(addTo814), zOutput.format(-(generalSettings.bAxisOffset - transformedPosition.z - 1.0 - tool.diameter / 2)), "T" + tool.number);
      writeBlock(gFormat.format(0), cOutput.format(abc.z));
      zOutput.reset();
      if (abc.y < 0 && abc.y > 90) {
        error("Manual B Axis toolpost HAS to be set between 0 and 90 - check " + getParameter("operation-comment"));
      }
      if (previousABCyManual != undefined) {
        if (previousABCyManual != abc.y) {
          error(localize("Manual B Axis toolpost HAS to be the same angle - " + previousAngledManual + " is " + bManualFormat.format(previousABCyManual) + " degrees and " + getParameter("operation-comment") + " is " + bManualFormat.format(abc.y) + " degrees"));
        }
      }
      writeBlock("#1=#[180500+#81314]");
      writeBlock("#2=#1-[#1*[SIN[" + bManualFormat.format(abc.y) + "]]]#3=[#1*[COS[" + bManualFormat.format(abc.y) + "]]]/2");
      writeBlock(gFormat.format(950) + "X" + spatialFormat.format(X) + "-#2 " + zOutput.format(0) + "+#81930-#3 D" + bManualFormat.format(abc.y));
      previousABCyManual = abc.y;

      previousAngledManual = getParameter("operation-comment");

      if (machineState.usePolarMode) {
        writeBlock(mFormat.format(212), "Y1");
        writeBlock(gMotionModal.format(50) + "X-#100450" + addTo814 + "Y0");
        zOutput.reset();
        writeBlock(gMotionModal.format(0) + zOutput.format(transformedPosition.z));
      }
    } else if (generalSettings.toolpost == "gangBaxisDriven") {
      var addTo814 = xyzFormat.format(tool.diameter * 2 + 1);
      if (generalSettings.newGen && hasParameter("operation:isMultiAxisStrategy") && hasParameter("operation:multiAxisMachiningType") && getParameter("operation:multiAxisMachiningType") == "five_axis" || machineState.usePolarMode) {
        yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-2});
        xOutput = createVariable({prefix:"X"}, xFormat);
        yOutput = createVariable({prefix:"Y"}, yFormat);
        gPlaneModal.reset();
        writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + addTo814, zOutput.format(0), tooloffsetOutput ? "" : "T" + tool.number);
        zOutput.reset();
        if (machineState.usePolarMode) {
          writeBlock("#1=#5022");
        }
        writeBlock(gFormat.format(920), generalSettings.safetyVal + "+" + addTo814, yOutput.format(0), zOutput.format(0), bOutput.format(abc.y), cOutput.format(0));
        if (machineState.usePolarMode) {
          writeBlock(gFormat.format(921));
          writeBlock("#2=#5022-#1");
          zOutput.reset();
          writeBlock(gFormat.format(50), generalSettings.safetyVal + "+" + addTo814, zOutput.format(0));
        }
      } else if (generalSettings.newGen) {
        yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-2});
        xOutput = createVariable({prefix:"X"}, xFormat);
        yOutput = createVariable({prefix:"Y"}, yFormat);
        gPlaneModal.reset();
        writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + addTo814, zOutput.format(-1.0 + (tool.diameter * 2) - 15), tooloffsetOutput ? "" : "T" + tool.number);
        zOutput.reset();
        writeBlock(gMotionModal.format(0), cOutput.format(abc.z));

        writeBlock(
          gFormat.format(930),
          "X" + spatialFormat.format(0),
          "Y" + spatialFormat.format(0),
          "Z" + spatialFormat.format(0),
          bFormat.format((getSpindle(true) == SPINDLE_MAIN) ? abc.y : -abc.y) // only B-axis is supported for G368
        );
        //writeBlock(gFormat.format(930), generalSettings.safetyVal + "+" + addTo814, yOutput.format(0), zOutput.format((-1.0 - tool.diameter / 2)*-1), bOutput.format(abc.y), cOutput.format(0));
      } else {
        gPlaneModal.reset();
        writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + addTo814, "Z" + zFormat.format(-(generalSettings.bAxisOffset - transformedPosition.z - 1.0 - tool.diameter / 2)), tooloffsetOutput ? "" : "T" + tool.number);
        zOutput.reset();
        // writeBlock(gMotionModal.format(900) + "X#100450+" + addTo814 + "Z"+(zFormat.format(transformedPosition.z)), bFormat.format(90 / 180 * Math.PI));
        writeBlock(gMotionModal.format(0), cOutput.format(abc.z));
        if (machineState.usePolarMode) {
          writeBlock(mFormat.format(212), "Y1");// + xyzFormat.format(1));
          writeBlock(gMotionModal.format(50) + "X-#100450-" + addTo814 + "Y0");//,  bFormat.format((getSpindle(true) == SPINDLE_MAIN) ? abc.y : -abc.y)/*bFormat.format(90 / 180 * Math.PI)*/);
          zOutput.reset();
          writeBlock(gMotionModal.format(0) + zOutput.format(transformedPosition.z));
          //writeBlock(gFormat.format(98));
        } else {
          writeBlock(
            gFormat.format(950),
            "X" + spatialFormat.format(0),
            "Z" + spatialFormat.format(0),
            bFormat.format((getSpindle(true) == SPINDLE_MAIN) ? abc.y : -abc.y) // only B-axis is supported for G368
          );
          tooloffsetOutput = true;
        }
        if (abc.y == 0) {
          yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-2});
          yOutput = createVariable({prefix:"Y"}, yFormat);
          xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:2});
          xOutput = createVariable({prefix:"X"}, xFormat);
        }
      }

    }
  }
  if ((getSpindle(false) == SPINDLE_LIVE) && machineConfiguration.isMachineCoordinate(2)) {
    if (getSpindle(true) == SPINDLE_MAIN) {
      if (!generalSettings.newGen) {
        if (generalSettings.toolpost == "oppositeEndWorking1" || generalSettings.toolpost == "backToolPostStatic") {

          writeBlock(gMotionModal.format(0), cOutput.format(getCClosest(initialPosition.x, initialPosition.y, cOutput.getCurrent(), false)));
        } else {
          writeBlock(gMotionModal.format(0), cOutput.format(abc.z));
        }
      }
    } else {
      if (!polarIsActive) {
        writeBlock(gMotionModal.format(0), "C", cFormat.format(abc.z));
      }
    }
  } else if (!currentSection.getParameter("operation-strategy") == "drill") {
    writeBlock(
      gMotionModal.format(0),
      conditional(machineConfiguration.isMachineCoordinate(0), aOutput.format(abc.x)),
      conditional(machineConfiguration.isMachineCoordinate(1), bFormat.format(abc.y)),
      conditional(machineConfiguration.isMachineCoordinate(2), cOutput.format(abc.z))
    );
  }

  currentWorkPlaneABC = new Vector(abc.x, abc.y, abc.z);
  previousABC = new Vector(abc.x, abc.y, abc.z);
}
function goHome() {
  debugSectionHeader("goHome");
  var yAxis = "";
  if (gotYAxis) {
    yAxis = "V" + yFormat.format(0);
  }
  gMotionModal.reset();
  zOutput.reset(); xOutput.reset();
  if (generalSettings.toolpost == "gangBaxisDriven") {
    writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + xFormat.format(tool.diameter + 1));
  } else {
    writeBlock(gMotionModal.format(0), generalSettings.safetyVal);
  }
}
function pointLineDistance(startPt, endPt, testPt) {
  var delta = Vector.diff(endPt, startPt);
  distance = Math.abs(delta.y * testPt.x - delta.x * testPt.y + endPt.x * startPt.y - endPt.y * startPt.x) /
    Math.sqrt(delta.y * delta.y + delta.x * delta.x); // distance from line to point
  if (distance < 1e-4) { // make sure point is in line segment
    var moveLength = Vector.diff(endPt, startPt).length;
    var startLength = Vector.diff(startPt, testPt).length;
    var endLength = Vector.diff(endPt, testPt).length;
    if ((startLength > moveLength) || (endLength > moveLength)) {
      distance = Math.min(startLength, endLength);
    }
  }
  return distance;
}
///////////////////////////////////////////////////////////////////////////////
//                        MANUAL NC COMMANDS
//
// The following ACTION commands are supported by this post.
//
//     useXZCMode                 - Force XZC mode for next operation
//     usePolarMode               - Force Polar mode for next operation
//
///////////////////////////////////////////////////////////////////////////////

extension = "txt";
programNameIsInteger = true;
setCodePage("ascii");

tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(120); // reduced sweep due to G112 support
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
highFeedrate = (unit == IN) ? 470 : 10000;

// user-defined properties
properties = {
  showSequenceNumbers    : false, // show sequence numbers
  sequenceNumberStart    : 1, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  optionalStop           : false, // optional stop
  useRadius              : true, // specifies that arcs should be output using the radius (R word) instead of the I, J, and K words.
  maximumSpindleSpeed    : 5000, // specifies the maximum spindle speed
  useParametricFeed      : true, // specifies that feed should be output using Q values
  highPressureCoolantCode: "",
  useG50OnGang           : false,
  leaveSpindleRunning    : true,
  subroutineAll          : false,
  subSpindlePhaseAngle   : 0,
  increaseBAxisStroke    : false
};

// user-defined property definitions
propertyDefinitions = {
  subSpindlePhaseAngle   : {title:"Sub Spindle Phase Angle", description:"The offset to shift the sub spindle C axis by.", group:1, type:"integer"},
  showSequenceNumbers    : {title:"Use sequence numbers", description:"Use sequence numbers for each block of outputted code.", group:1, type:"boolean"},
  sequenceNumberStart    : {title:"Start sequence number", description:"The number at which to start the sequence numbers.", group:1, type:"integer"},
  sequenceNumberIncrement: {title:"Sequence number increment", description:"The amount by which the sequence number is incremented by in each block.", group:1, type:"integer"},
  optionalStop           : {title:"Optional stop", description:"Outputs optional stop code during when necessary in the code.", type:"boolean"},
  useRadius              : {title:"Radius arcs", description:"If yes is selected, arcs are outputted using radius values rather than IJK.", type:"boolean"},
  maximumSpindleSpeed    : {title:"Max spindle speed", description:"Defines the maximum spindle speed allowed by your machines.", type:"integer", range:[0, 999999999]},
  useParametricFeed      : {title:"Parametric feed", description:"Specifies the feed value that should be output using a Q value.", type:"boolean"},
  useG50OnGang           : {title:"Use G50 offset", description:"Specifies whether to use G50 shifts on Gang", type:"boolean"},
  subroutineAll          : {title:"Subroutine all Operations", description:"Specifies whether the code should be output useable as sub programs for drip feeding", type:"boolean"},
  highPressureCoolantCode: {title:"High Pressure Coolant Code", description:"High Pressure Coolant Code - blank for none", group:0, type:"string"},
  leaveSpindleRunning    : {title:"Leave Spindles Running", description:"Leave Spindles Running at the end of each Toolpath?", group:0, type:"boolean"},
  increaseBAxisStroke    : {title:"Increase B Axis Stroke", description:"Increase B Axis Stroke to 111 degrees", group:0, type:"boolean"}
};

//Properties removed from post properties dialog
var sequenceNumberToolOnly = false;
var useG400 = false;
var transferUseTorque = false;
var optimizeCaxisSelect = false;
var separateWordsWithSpace = true;
var showNotes = false;
var useCycles = true;
var useSimpleThread = false;
//-----------------------------------------------
var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";
var spatialFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.xScale ? generalSettings.xScale : 1}); // diameter mode & IS SCALING POLAR COORDINATES
var yFormat = createFormat({decimals:(unit == MM ? 3 : 3), forceDecimal:true});
var yPolarFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "backToolPostStatic" ? 1 : 1});
var zFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var rFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true}); // radius
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var bFormat = createFormat({prefix:"B", decimals:3, forceDecimal:true, scale:DEG});
var bManualFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var cFormat = createFormat({decimals:3, type:FORMAT_REAL, scale:DEG});
//var cFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG, cyclicLimit:Math.PI * 2});
var eFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var fpmFormat = createFormat({decimals:(unit == MM ? 0 : 3), type:FORMAT_INTEGER});
var fprFormat = createFormat({type:FORMAT_REAL, decimals:(unit == MM ? 3 : 4), minimum:(unit == MM ? 0.001 : 0.0001)});
var feedFormat = fpmFormat;
//var feedFormat = createFormat({decimals:(unit == MM ? 2 : 3), forceDecimal:true});
var pitchFormat = createFormat({decimals:6, forceDecimal:true});
var toolFormat = createFormat({decimals:0, width:4, zeropad:true});
var rpmFormat = createFormat({decimals:0});
var cssOutput = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-99999.999
var milliFormat = createFormat({decimals:0}); // milliseconds // range 1-9999
var taperFormat = createFormat({decimals:1, scale:DEG});
var qFormat = createFormat({decimals:3, forceDecimal:true, trim:false, width:4, zeropad:true, scale:(unit == MM ? 1 : 10)});
var threadP1Format = createFormat({decimals:0, forceDecimal:false, trim:false, width:6, zeropad:true});
var threadPQFormat = createFormat({decimals:3, forceDecimal:true, trim:true, scale:(unit == MM ? 1 : 10)});
var threadRFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true}); // radius

var dwellFormat = createFormat({prefix:"U", decimals:3});

var xOutput = createVariable({prefix:"X"}, xFormat);
var yOutput = createVariable({prefix:"Y"}, yFormat);
var zOutput = createVariable({prefix:"Z"}, zFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({}, bFormat);
//var cOutput = createVariable({prefix:"C"}, cFormat);
var cOutput = createOutputVariable({prefix:"C", cyclicLimit:360}, cFormat);
var eOutput = createVariable({prefix:"C"}, eFormat);
var eValueOutput = createVariable({prefix:"E"}, cFormat);
var barOutput = createVariable({prefix:"B", force:true}, spatialFormat);
var initialB;
//var feedOutput = createVariable({prefix:"F"}, feedFormat);
var feedOutput = createOutputVariable({prefix:"F"}, feedFormat);
var pitchOutput = createVariable({prefix:"F", force:true}, pitchFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);

var rpmOutput = createVariable({force:true}, rpmFormat);
var pOutput = createVariable({prefix:"P", force:true}, rpmFormat);
var qOutput = createVariable({prefix:"Q", force:true}, qFormat);
var rOutput = createVariable({prefix:"R", force:true}, rFormat);
var threadP1Output = createVariable({prefix:"P", force:true}, threadP1Format);
var threadP2Output = createVariable({prefix:"P", force:true}, threadPQFormat);
var threadQOutput = createVariable({prefix:"Q", force:true}, threadPQFormat);
var threadROutput = createVariable({prefix:"R", force:true}, threadRFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I", force:true}, spatialFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, spatialFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, spatialFormat);
var outputDocuments = [];

var g92ROutput = createVariable({prefix:"R", force:true}, zFormat); // no scaling

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G98-99
var gSpindleModeModal = createModal({}, gFormat); // modal group 5 // G96-97
var gSpindleModal = createModal({}, mFormat); // M176/177 SPINDLE MODE
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81, ...
var gPolarModal = createModal({}, g1Format); // G12.1, G13.1
var cAxisBrakeModal = createModal({}, mFormat);
var mInterferModal = createModal({}, mFormat);
var cAxisEngageModal = createModal({}, mFormat);
var gWCSModal = createModal({}, g1Format);
var tailStockModal = createModal({}, mFormat);

// fixed settings
var firstFeedParameter = 100;
var airCleanChuck = true; // use air to clean off chuck at part transfer and part eject

var POSX = 0;
var POXY = 1;
var POSZ = 2;
var NEGZ = -2;

// defined in definedMachine
var bAxisIsManual, gotBAxis, gotDoorControl, gotMultiTurret,
  gotPolarInterpolation, gotSecondarySpindle, gotYAxis, xAxisMinimum,
  yAxisMaximum, yAxisMinimum;

var WARNING_WORK_OFFSET = 0;
var WARNING_REPEAT_TAPPING = 1;

var SPINDLE_MAIN = 0;
var SPINDLE_SUB = 1;
var SPINDLE_LIVE = 2;
// collected state
var activeMovements, currentFeedId, currentWorkOffset, previousSpindle,
  sequenceNumber, transferUseTorque;
var previousangle;
var optionalSection = false;
var forceSpindleSpeed = false;
var activeSpindle = 0;
var partCutoff = false;
var reverseTap = false;
var showSequenceNumbers;
var leaveSpindleRunning;
var highPressureCoolantCode;
var forceXZCMode = false; // forces XZC output, activated by Action:useXZCMode
var forcePolarMode = false; // force Polar output, activated by Action:usePolarMode
var tapping = false;
var ejectRoutine = false;
var bestABCIndex = undefined;
var headOffset = 0;
var debugMode = false;
var base64encoded = true;
var previousABCyManual = undefined;
var previousAngledManual;
var subroutineAll;

var subroutineNumber = 10;
var subroutineNumberIncrement = 10;
var subroutineStart = 10;

var machineState = {
  liveToolIsActive              : undefined,
  cAxisIsEngaged                : undefined,
  machiningDirection            : undefined,
  mainSpindleIsActive           : undefined,
  subSpindleIsActive            : undefined,
  mainSpindleBrakeIsActive      : undefined,
  subSpindleBrakeIsActive       : undefined,
  tailstockIsActive             : undefined,
  usePolarMode                  : undefined,
  useXZCMode                    : undefined,
  axialCenterDrilling           : undefined,
  currentBAxisOrientationTurning: new Vector(0, 0, 0)
};

/** Returns the modulus. */
function getModulus(x, y) {
  return Math.sqrt(x * x + y * y);
}

/**
  Returns the C rotation for the given X and Y coordinates.
*/
function getC(x, y) {
  var direction;
  if (Vector.dot(machineConfiguration.getAxisU().getAxis(), new Vector(0, 0, 1)) != 0) {
    direction = (machineConfiguration.getAxisU().getAxis().getCoordinate(2) >= 0) ? 1 : 1; // C-axis is the U-axis
  } else {
    direction = (machineConfiguration.getAxisV().getAxis().getCoordinate(2) >= 0) ? 1 : 1; // C-axis is the V-axis
  }

  return Math.atan2(y, x) * direction;
}

/**
  Returns the C rotation for the given X and Y coordinates in the desired rotary direction.
*/
function getCClosest(x, y, _c, clockwise) {
  if (_c == Number.POSITIVE_INFINITY) {
    _c = 0; // undefined
  }
  if (!xFormat.isSignificant(x) && !yFormat.isSignificant(y)) { // keep C if XY is on center
    return _c;
  }
  var c = getC(x, y);
  if (clockwise != undefined) {
    if (clockwise) {
      while (c < _c) {
        c += Math.PI * 2;
      }
    } else {
      while (c > _c) {
        c -= Math.PI * 2;
      }
    }
  } else {
    min = _c - Math.PI;
    max = _c + Math.PI;
    while (c < min) {
      c += Math.PI * 2;
    }
    while (c > max) {
      c -= Math.PI * 2;
    }
  }
  return c;
}

/**
  Returns the desired tolerance for the given section.
*/
function getTolerance() {
  var t = tolerance;
  if (hasParameter("operation:tolerance")) {
    if (t > 0) {
      t = Math.min(t, getParameter("operation:tolerance"));
    } else {
      t = getParameter("operation:tolerance");
    }
  }
  return t;
}

function formatSequenceNumber() {
  if (sequenceNumber > 99999) {
    sequenceNumber = properties.sequenceNumberStart;
  }
  var seqno = "N" + sequenceNumber;
  sequenceNumber += properties.sequenceNumberIncrement;
  return seqno;
}

function formatSubProgramNumber() {
  if (properties.subroutineAll && !showSequenceNumbers) {
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

/**
  Writes the specified block.
*/
const base64buffer = "";

function writeBlock() {
  var seqno = "";
  var opskip = "";
  if (showSequenceNumbers) {
    seqno = formatSequenceNumber();
  }
  if (optionalSection) {
    opskip = "/";
  }
  var text = formatWords(arguments);
  if (text) {
    writeWords(opskip, seqno, text);
  }
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

var machineConfigurationMainSpindle;
var machineConfigurationSubSpindle;
var machineConfigurationZ;
var machineConfigurationXC;
var machineConfigurationXB;

// due to an API bug
function verifyProps() {
  if (typeof properties.showSequenceNumbers == "string") {
    if (properties.showSequenceNumbers.toLowerCase() == "false") {
      properties.showSequenceNumbers = false;
    } else {
      properties.showSequenceNumbers = true;
    }
  }
  if (typeof properties.optionalStop == "string") {
    if (properties.optionalStop.toLowerCase() == "false") {
      properties.optionalStop = false;
    } else {
      properties.optionalStop = true;
    }
  }
  if (typeof properties.useRadius == "string") {
    if (properties.useRadius.toLowerCase() == "false") {
      properties.useRadius = false;
    } else {
      properties.useRadius = true;
    }
  }

  if (typeof properties.useG50OnGang == "string") {
    if (properties.useG50OnGang.toLowerCase() == "false") {
      properties.useG50OnGang = false;
    } else {
      properties.useG50OnGang = true;
    }
  }

  if (typeof properties.subroutineAll == "string") {
    if (properties.subroutineAll.toLowerCase() == "false") {
      properties.subroutineAll = false;
    } else {
      properties.subroutineAll = true;
    }
  }

  if (typeof properties.useParametricFeed == "string") {
    if (properties.useParametricFeed.toLowerCase() == "false") {
      properties.useParametricFeed = false;
    } else {
      properties.useParametricFeed = true;
    }
  }

  if (typeof properties.leaveSpindleRunning == "string") {
    if (properties.leaveSpindleRunning.toLowerCase() == "false") {
      properties.leaveSpindleRunning = false;
    } else {
      properties.leaveSpindleRunning = true;
    }
  }
}

function onOpen() {
  verifyProps();
  if (debugMode) {
    if (unit == MM) {
      writeBlock("MM");
    } else {
      writeBlock("IN");
    }
  }
  if (properties.useRadius) {
    maximumCircularSweep = toRad(90); // avoid potential center calculation errors for CNC
  }

  // Copy certain properties into global variables
  showSequenceNumbers = sequenceNumberToolOnly ? false : properties.showSequenceNumbers;

  // Setup default M-codes
  mInterferModal.format(getCode("INTERFERENCE_CHECK_ON", SPINDLE_MAIN));

  machineConfiguration = new MachineConfiguration(); // creates an empty configuration to be able to set eg vendor information

  if (highFeedrate <= 0) {
    error(localize("You must set 'highFeedrate' because axes are not synchronized for rapid traversal."));
    return;
  }
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }
  sequenceNumber = properties.sequenceNumberStart;
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
  previousDPMFeed = 0;
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

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
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

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
}

function formatFeedMode(mode) {
  var fMode = (mode == FEED_PER_REVOLUTION || tapping) ? getCode("FEED_MODE_MM_MIN") : getCode("FEED_MODE_MM_REV");
  if (fMode) {
    feedFormat = mode == FEED_PER_REVOLUTION ? fprFormat : fpmFormat;
    feedOutput.setFormat(feedFormat);
  }
  return gFeedModeModal.format(fMode);
}

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function getTCP(abc) {
  tcp = gotBAxis &&
    (machineState.axialCenterDrilling ||
      (useG400 && (Math.abs(bFormat.getResultingValue(abc.y)) == 90)) ||
      (machineState.usePolarMode || machineState.useXZCMode));
  return tcp;
}

function getBestABC(section, workPlane, which) {
  var W = workPlane;
  var abc = machineConfiguration.getABC(W);
  if (which == undefined) { // turning, XZC, Polar modes
    return abc;
  }
  if (Vector.dot(machineConfiguration.getAxisU().getAxis(), new Vector(0, 0, 1)) != 0) {
    var axis = machineConfiguration.getAxisU(); // C-axis is the U-axis
  } else {
    var axis = machineConfiguration.getAxisV(); // C-axis is the V-axis
  }
  if (axis.isEnabled() && axis.isTable()) {
    var ix = axis.getCoordinate();
    var rotAxis = axis.getAxis();
    if (isSameDirection(machineConfiguration.getDirection(abc), rotAxis) ||
      isSameDirection(machineConfiguration.getDirection(abc), Vector.product(rotAxis, -1))) {
      var direction = isSameDirection(machineConfiguration.getDirection(abc), rotAxis) ? 1 : -1;
      var box = section.getGlobalBoundingBox();
      switch (which) {
      case 1:
        x = box.upper.x - box.lower.x;
        y = box.upper.y - box.lower.y;
        break;
      case 2:
        x = box.lower.x;
        y = box.lower.y;
        break;
      case 3:
        x = box.upper.x;
        y = box.lower.y;
        break;
      case 4:
        x = box.upper.x;
        y = box.upper.y;
        break;
      case 5:
        x = box.lower.x;
        y = box.upper.y;
        break;
      default:
        var tempABC = new Vector(0, 0, 0); // don't use B-axis in calculation
        tempABC.setCoordinate(ix, abc.getCoordinate(ix));
        var R = machineConfiguration.getRemainingOrientation(tempABC, W);
        x = R.right.x;
        y = R.right.y;
        break;
      }
      abc.setCoordinate(ix, getCClosest(x, y, cOutput.getCurrent()));
    }
  }
  return abc;
}

var closestABC = false; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(section, workPlane) {
  var W = workPlane; // map to global frame
  var abc = getBestABC(section, workPlane, bestABCIndex);
  if (closestABC) {
    if (currentMachineABC) {
      abc = machineConfiguration.remapToABC(abc, currentMachineABC);
    } else {
      abc = machineConfiguration.getPreferredABC(abc);
    }
  } else {
    abc = machineConfiguration.getPreferredABC(abc);
  }
  try {
    abc = machineConfiguration.remapABC(abc);
    currentMachineABC = abc;
  } catch (e) {
    error(
      localize("Machine angles not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " " + bFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + cFormat.format(abc.z))
    );
    return abc;
  }
  var direction = machineConfiguration.getDirection(abc);
  if (!isSameDirection(direction, W.forward)) {
    error(localize("Orientation not supported."));
    return abc;
  }
  if (!machineConfiguration.isABCSupported(abc)) {
    error(
      localize("Work plane is not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " " + bFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + cFormat.format(abc.z))
    );
    return abc;
  }

  var tcp = getTCP(abc);
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);

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
  var spindleMain = getSpindle(true) == SPINDLE_MAIN;

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

  if (insertToolCall || machineState.currentBAxisOrientationTurning.y != bAxisOrientationTurning.y || (previousSpindle != getSpindle(true))) {
    if (spindleMain) {
      var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
    } else {
      var compensationOffset = (tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset) + 100;
    }
    if (!spindleMain) {
      bAxisOrientationTurning.y *= -1;
    }
  }
  machineState.currentBAxisOrientationTurning.y = Math.abs(bAxisOrientationTurning.y);
}

function getBAxisOrientationTurning(section) {
  var toolAngle = hasParameter("operation:tool_angle") ? getParameter("operation:tool_angle") : 0;
  var toolOrientation = section.toolOrientation;
  if (toolAngle && toolOrientation != 0) {
    error(localize("You cannot use tool angle and tool orientation together in operation " + "\"" + (getParameter("operation-comment")) + "\""));
  }

  var angle = toRad(toolAngle) + toolOrientation;

  var direction;
  if (Vector.dot(machineConfiguration.getAxisU().getAxis(), new Vector(0, 1, 0)) != 0) {
    direction = (machineConfiguration.getAxisU().getAxis().getCoordinate(1) >= 0) ? 1 : -1; // B-axis is the U-axis
  } else {
    direction = (machineConfiguration.getAxisV().getAxis().getCoordinate(1) >= 0) ? 1 : -1; // B-axis is the V-axis
  }
  var mappedWorkplane = new Matrix(new Vector(0, direction, 0), Math.PI / 2 - angle);
  var abc = getWorkPlaneMachineABC(section, mappedWorkplane);

  return abc;
}

function setSpindleOrientationMilling(abc) {
  if (useG400) {
    var J;
    switch (getSpindle(false)) {
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
    writeBlock(mFormat.format(101)); // clamp B-axis
  } else {
    if (gWCSModal.getCurrent() != 369) { // TAG: Move to not useG400
      writeBlock(gFormat.format(369));
    }
    bOutput.reset();
    writeBlock(gMotionModal.format(0), bOutput.format(getB(abc, currentSection)));
  }
}

function getSpindle(partSpindle) {
  // safety conditions
  if (getNumberOfSections() == 0) {
    return SPINDLE_MAIN;
  }
  if (getCurrentSectionId() < 0) {
    if (machineState.liveToolIsActive && !partSpindle) {
      return SPINDLE_LIVE;
    } else {
      return getSection(getNumberOfSections() - 1).spindle;
    }
  }

  // Turning is active or calling routine requested which spindle part is loaded into
  if (machineState.isTurningOperation || machineState.axialCenterDrilling || partSpindle) {
    return currentSection.spindle;
    //Milling is active
  } else {
    return SPINDLE_LIVE;
  }
}

function getSecondarySpindle() {
  var spindle = getSpindle(true);
  return (spindle == SPINDLE_MAIN) ? SPINDLE_SUB : SPINDLE_MAIN;
}

function isPerpto(a, b) {
  return Math.abs(Vector.dot(a, b)) < (1e-7);
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
let GroupedbAxis = false;

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

function onSection() {
  debugSectionHeader("onSection");

  setMachineStyle(tool);
  if (!gotBAxis) {
    bOutput.disable();
  } else {
    if (generalSettings.toolpost == "gangCrossWorking" || generalSettings.toolpost == "gangEndWorking") {
      bOutput.disable();
    } else {
      bOutput.enable();
    }
  }

  // used to output the section
  debugSectionHeader("redirectSection");

  shouldRedirect = !groupedOperations || isFirstSection() || tool.number != getPreviousSection().getTool().number;
  if ((groupedOperations && hasParameter("operation:isMultiAxisStrategy") && (getParameter("operation:isMultiAxisStrategy") != 0))) {
    error(localize("Grouped 5 Axis Simultaneous Operations are currently not supported."));
  }
  if (shouldRedirect || !redirectStarted) {

    if (!debugMode && isRedirecting()) {
      closeSection();
      closeRedirection();
      b64Output();
    }
    redirectSection();

  }
  // ****************************************************************************************** formatSubProgramNumber();

  // setup machine
  debugSectionHeader("setupMachine");

  setupMachine();

  debugSectionHeader("setScaling");

  setScaling(tool.number);

  //formatSubProgramNumber();
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    writeBlock(formatComment(comment));
  }

  //if (generalSettings.toolpost == "oppositeEndWorking1" || generalSettings.toolpost == "oppositeEndWorking2") {
  //  if (!redirectStarted) {
  //    writeBlock(formatComment("G610 MODE ONLY"))
  // }
  // }

  setMachineConfiguration(machineConfiguration);
  currentSection.optimizeMachineAnglesByMachine(machineConfiguration, OPTIMIZE_NONE); // map tip mode

  tapping = hasParameter("operation:cycleType") &&
    ((getParameter("operation:cycleType") == "tapping") ||
      (getParameter("operation:cycleType") == "right-tapping") ||
      (getParameter("operation:cycleType") == "left-tapping") ||
      (getParameter("operation:cycleType") == "tapping-with-chip-breaking"));
  machineState.isTurningOperation = (currentSection.getType() == TYPE_TURNING);
  updateMachiningMode(currentSection); // sets the needed machining mode to machineState (usePolarMode, useXZCMode, axialCenterDrilling)

  if (properties.useParametricFeed &&
    hasParameter("operation-strategy") &&
    (getParameter("operation-strategy") != "drill") && // legacy
    !(currentSection.hasAnyCycle && currentSection.hasAnyCycle())) {
    if (!(!insertToolCall &&
      activeMovements &&
      (getCurrentSectionId() > 0) &&
      ((getPreviousSection().getPatternId() == currentSection.getPatternId()) && (currentSection.getPatternId() != 0)))) {
      initializeActiveFeeds();
    } else {
      activeMovements = undefined;
    }
  }
  // predefined variables
  optionalSection = currentSection.isOptional();
  bestABCIndex = undefined;
  var insertToolCall = true;
  var retracted = false; // specifies that the tool has been retracted to the safe plane

  // define if the current operation is parting
  partCutoff = hasParameter("operation-strategy") &&
    (getParameter("operation-strategy") == "turningPart");

  //------------------------------------
  // Get the active spindle
  var newSpindle = true;
  var tempSpindle = getSpindle(false);
  if (isFirstSection()) {
    previousSpindle = tempSpindle;
  }
  newSpindle = tempSpindle != previousSpindle;
  headOffset = tool.getBodyLength();

  var abc;
  if (machineConfiguration.isMultiAxisConfiguration()) {
    if (machineState.isTurningOperation) {
      if (gotBAxis) {
        cancelTransformation();

        // handle B-axis support for turning operations here
        bAxisOrientationTurning = getBAxisOrientationTurning(currentSection);
        abc = bAxisOrientationTurning;
      } else {

        abc = getWorkPlaneMachineABC(currentSection, currentSection.workPlane);
      }
    } else {
      if (currentSection.isMultiAxis()) {
        forceWorkPlane();
        cancelTransformation();
        //onCommand(COMMAND_UNLOCK_MULTI_AXIS);
        abc = currentSection.getInitialToolAxisABC();
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
  if (shouldRedirect || !redirectStarted) {
    debugSectionHeader("safeStartSection");
    safeStartSection(tempSpindle, newSpindle, abc);
    closedSection = false;
  }
  // Setup WCS code
  currentWorkOffset = undefined;
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (workOffset > 6) {
      error(localize("Work offset out of range."));
      return;
    } else {
      if (workOffset != currentWorkOffset) {
        forceWorkPlane();
        wcsOut = gFormat.format(53 + workOffset); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }

  // Get active feedrate mode
  gFeedModeModal.reset();
  // var feedMode
  var feedMode = formatFeedMode(currentSection.feedMode);
  if ((currentSection.feedMode == FEED_PER_REVOLUTION) || tapping) {
    feedMode = gFeedModeModal.format(getCode("FEED_MODE_MM_REV", getSpindle(false)));
    machineState.feedPerRevolution = true;
  } else {
    feedMode = gFeedModeModal.format(getCode("FEED_MODE_MM_MIN", getSpindle(false)));
    machineState.feedPerRevolution = false;
  }

  // Write out notes
  if (showNotes && hasParameter("notes")) {
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
  }
  switch (getMachiningDirection(currentSection)) {
  case MACHINING_DIRECTION_AXIAL:
  case MACHINING_DIRECTION_RADIAL:
  case MACHINING_DIRECTION_INDEXING:
    break;
  default:
    error(subst(localize("Unsupported machining direction for operation " + "\"" + "%1" + "\"" + "."), getOperationComment()));
    return;
  }

  currentABC = abc;
  forceAny();
  gMotionModal.reset();
  gPlaneModal.reset();
  if (currentSection.isMultiAxis()) {
    previousABC = abc;
    forceWorkPlane();
    cancelTransformation();
    workplaneActive = true;
    if (!currentSection.isMultiAxis() && generalSettings.toolpost == "gangBaxisDriven") {
      var initialPosition = currentSection.getInitialPosition();
      var matrixTest = machineConfiguration.getRemainingOrientation(new Vector(0, 0, 1), currentSection.workPlane);
      var transformedPosition = matrixTest.multiply(initialPosition);
      var addTo814 = xFormat.format((tool.diameter + 1) * -1);
      gPlaneModal.reset();
      writeBlock(gMotionModal.format(0), generalSettings.safetyVal + "+" + addTo814, xOutput.format(-(generalSettings.bAxisOffset - transformedPosition.z - 1.0 - tool.diameter / 2)), GroupedbAxis ? "" : "T" + tool.number);
      zOutput.reset();
      writeBlock(gMotionModal.format(900) + "X#100450+" + addTo814 + xOutput.format(transformedPosition.z), bFormat.format(abc.y /*90/180*Math.PI*/));
      writeBlock(gMotionModal.format(0), aOutput.format(abc.x), bOutput.format(abc.y), cOutput.format(abc.z));
      writeBlock(
        gFormat.format(950),
        "X" + spatialFormat.format(0),
        "Z" + spatialFormat.format(0),
        //"D" + spatialFormat.format(toolAxisMode),
        bFormat.format((getSpindle(true) == SPINDLE_MAIN) ? abc.y : -abc.y) // only B-axis is supported for G368
        //"W" + compensationOffset
      );
    } else {
      if (machineState.isTurningOperation && gotBAxis && !bAxisIsManual) {
        setSpindleOrientationTurning(insertToolCall);
      } else if (machineState.isTurningOperation) {
        if (gotBAxis) {
          setSpindleOrientationMilling(abc);
        }
      } else if (gotBAxis && !bAxisIsManual) {
        setWorkPlane(abc);
      } else if (!machineState.isTurningOperation && !machineState.axialCenterDrilling && !machineState.useXZCMode && !machineState.usePolarMode) {
        setWorkPlane(abc);
      }
    }
  } else {
    if (machineState.isTurningOperation && gotBAxis && !bAxisIsManual) {
      workplaneActive = true;
      setSpindleOrientationTurning(insertToolCall);
    } else if (machineState.isTurningOperation) {
      if (gotBAxis) {
        setSpindleOrientationMilling(abc);
      }
    } else if (gotBAxis && !bAxisIsManual) {
      setWorkPlane(abc);
    } else if (!machineState.isTurningOperation && !machineState.axialCenterDrilling && !machineState.useXZCMode && !machineState.usePolarMode) {
      setWorkPlane(abc);
    }

  }

  //forceAny();
  forceXYZ();
  if (abc !== undefined) {
    cOutput.format(abc.z); // make C current - we do not want to output here
  }
  gMotionModal.reset();
  if (shouldRedirect || !redirectStarted) {
    debugSectionHeader("initialPositioning");
    initialPositioning(abc);
    redirectStarted = true;
  }
  // enable SFM spindle speed
  if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
    //startSpindle(false, false);
  }

  if (machineState.usePolarMode) {
    setPolarMode(true); // enable polar interpolation mode
  }

  previousSpindle = tempSpindle;
  activeSpindle = tempSpindle;

  debugSectionHeader("DEBUG Values");
  if (debugMode) { // DEBUG
    for (var key in machineState) {
      writeComment(key + " : " + machineState[key]);
    }
    writeComment("Machining direction = " + getMachiningDirection(currentSection));
    writeComment("Tapping = " + tapping);
    // writeln("(" + (getMachineConfigurationAsText(machineConfiguration)) + ")");
  }
}

/** Returns true if the toolpath fits within the machine XY limits for the given C orientation. */
function doesToolpathFitInXYRange(abc) {
  var c = 0;
  if (abc) {
    c = abc.z;
  }

  var dx = new Vector(Math.cos(c), Math.sin(c), 0);
  var dy = new Vector(Math.cos(c + Math.PI / 2), Math.sin(c + Math.PI / 2), 0);

  if (currentSection.getGlobalRange) {
    var xRange = currentSection.getGlobalRange(dx);
    var yRange = currentSection.getGlobalRange(dy);

    if (debugMode) { // DEBUG
      writeComment("toolpath X min: " + xFormat.format(xRange[0]) + ", " + "Limit " + xFormat.format(xAxisMinimum));
      writeComment("X-min within range: " + (xFormat.getResultingValue(xRange[0]) >= xFormat.getResultingValue(xAxisMinimum)));
      writeComment("toolpath Y min: " + spatialFormat.getResultingValue(yRange[0]) + ", " + "Limit " + yAxisMinimum);
      writeComment("Y-min within range: " + (spatialFormat.getResultingValue(yRange[0]) >= yAxisMinimum));
      writeComment("toolpath Y max: " + (spatialFormat.getResultingValue(yRange[1]) + ", " + "Limit " + yAxisMaximum));
      writeComment("Y-max within range: " + (spatialFormat.getResultingValue(yRange[1]) <= yAxisMaximum));
    }

    if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) { // G19 plane
      if ((spatialFormat.getResultingValue(yRange[0]) >= yAxisMinimum) &&
        (spatialFormat.getResultingValue(yRange[1]) <= yAxisMaximum)) {
        return true; // toolpath does fit in XY range
      } else {
        return false; // toolpath does not fit in XY range
      }
    } else { // G17 plane
      if ((xFormat.getResultingValue(xRange[0]) >= xFormat.getResultingValue(xAxisMinimum)) &&
        (spatialFormat.getResultingValue(yRange[0]) >= yAxisMinimum) &&
        (spatialFormat.getResultingValue(yRange[1]) <= yAxisMaximum)) {
        return true; // toolpath does fit in XY range
      } else {
        return false; // toolpath does not fit in XY range
      }
    }
  } else {
    return false; // for older versions without the getGlobalRange() function
  }
}

var MACHINING_DIRECTION_AXIAL = 0;
var MACHINING_DIRECTION_RADIAL = 1;
var MACHINING_DIRECTION_INDEXING = 2;

function getMachiningDirection(section) {
  var forward = section.workPlane.forward;
  if (isSameDirection(forward, new Vector(0, 0, 1))) {
    return MACHINING_DIRECTION_AXIAL;
  } else if (Vector.dot(forward, new Vector(0, 0, 1)) < 1e-7) {
    return MACHINING_DIRECTION_RADIAL;
  } else {
    return MACHINING_DIRECTION_INDEXING;
  }
}

function updateMachiningMode(section) {
  if (!groupedOperations) {
    debugSectionHeader("updateMachiningMode");
    machineState.axialCenterDrilling = false; // reset
    machineState.usePolarMode = false; // reset
    machineState.useXZCMode = false; // reset
    if ((section.getType() == TYPE_MILLING) && !section.isMultiAxis()) {
      if (!gotYAxis) {
        if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
          forcePolarMode = true;
        } else {
          forceXZCMode = true;
        }
      }
      if (getMachiningDirection(section) == MACHINING_DIRECTION_AXIAL) {
        if (section.hasParameter("operation-strategy") && (section.getParameter("operation-strategy") == "drill")) {
          // drilling axial
          if ((section.getNumberOfCyclePoints() == 1) &&
            !xFormat.isSignificant(getGlobalPosition(section.getInitialPosition()).x) &&
            !yFormat.isSignificant(getGlobalPosition(section.getInitialPosition()).y) &&
            (spatialFormat.format(section.getFinalPosition().x) == 0) &&
            !doesCannedCycleIncludeYAxisMotion()) { // catch drill issue for old versions
            // single hole on XY center
            if (section.getTool().isLiveTool && section.getTool().isLiveTool()) {
              // use live tool
            } else {
              // use main spindle for axialCenterDrilling
              machineState.axialCenterDrilling = true;
            }
          }
        } else { // milling
          if ((gotPolarInterpolation && forcePolarMode) && !forceXZCMode) { // polar mode is requested by user
            machineState.usePolarMode = true;
          } else if (forceXZCMode) { // XZC mode is requested by user
            machineState.useXZCMode = true;
          } else { // see if toolpath fits in XY-range
            fitFlag = false;
            bestABCIndex = undefined;
            for (var i = 0; i < 6; ++i) {
              fitFlag = doesToolpathFitInXYRange(getBestABC(section, section.workPlane, i));
              if (fitFlag) {
                bestABCIndex = i;
                break;
              }
            }
            if (!fitFlag) { // does not fit, set polar/XZC mode
              if (gotPolarInterpolation) {
                machineState.usePolarMode = true;
              } else {
                machineState.useXZCMode = true;
              }
            }
          }
        }
      } else if (getMachiningDirection(section) == MACHINING_DIRECTION_RADIAL) { // G19 plane
        if (!gotYAxis) {
          if (!section.isMultiAxis() && !doesToolpathFitInXYRange(machineConfiguration.getABC(section.workPlane)) && doesCannedCycleIncludeYAxisMotion()) {
            error(subst(localize("Y-axis motion is not possible without a Y-axis for operation \"%1\"."), getOperationComment()));
            return;
          }
        } else {
          if (!doesToolpathFitInXYRange(machineConfiguration.getABC(section.workPlane)) || forceXZCMode) {
            error(subst(localize("Toolpath exceeds the maximum ranges for operation \"%1\"."), getOperationComment()));
            return;
          }
        }
        // C-coordinates come from setWorkPlane or is within a multi axis operation, we cannot use the C-axis for non wrapped toolpathes (only multiaxis works, all others have to be into XY range)
      } else {
        // useXZCMode & usePolarMode is only supported for axial machining, keep false
      }
    } else {
      // turning or multi axis, keep false
    }

    // if (machineState.axialCenterDrilling) {
    //   cOutput.disable();
    // } else {
    cOutput.enable();
    // }

    var checksum = 0;
    checksum += machineState.usePolarMode ? 1 : 0;
    checksum += machineState.useXZCMode ? 1 : 0;
    checksum += machineState.axialCenterDrilling ? 1 : 0;
    validate(checksum <= 1, localize("Internal post processor error."));
    if (generalSettings.toolpost == "backToolPostStatic" || generalSettings.toolpost == "subCrossWorking" && getMachiningDirection(section) == MACHINING_DIRECTION_AXIAL) {
      if (!currentSection.isMultiAxis() && (!getParameter("operation:strategy") == "drill")) {
        machineState.usePolarMode = true;
      }
    }

  }
}

function doesCannedCycleIncludeYAxisMotion() {
  // these cycles have Y axis motions which are not detected by getGlobalRange()
  var hasYMotion = false;
  if (hasParameter("operation:strategy") && (getParameter("operation:strategy") == "drill")) {
    switch (getParameter("operation:cycleType")) {
    case "thread-milling":
    case "bore-milling":
    case "circular-pocket-milling":
      hasYMotion = true; // toolpath includes Y-axis motion
      break;
    case "back-boring":
    case "fine-boring":
      var shift = getParameter("operation:boringShift");
      if (shift != spatialFormat.format(0)) {
        hasYMotion = true; // toolpath includes Y-axis motion
      }
      break;
    default:
      hasYMotion = false; // all other cycles don't have Y-axis motion
    }
  } else {
    hasYMotion = true;
  }
  return hasYMotion;
}

function getOperationComment() {
  var operationComment = hasParameter("operation-comment") && getParameter("operation-comment");
  return operationComment;
}

let polarIsActive = false;

function setPolarMode(activate) {
  if (activate) {
    cOutput.enable();
    if (!polarIsActive) {
      // writeBlock(gFormat.format(0), "C0"); // set C-axis to 0 to avoid G112 issues
      writeBlock(gPolarModal.format(getCode("POLAR_INTERPOLATION_ON", getSpindle(true))) + "D0E=C"); // command for polar interpolation
      writeBlock(gPlaneModal.format(17));
    }
    if (generalSettings.toolpost == "gangBaxisDriven") {
      yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:1});
    } else if (generalSettings.toolpost == "backToolPostStatic") {
      yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-1});
    } else if (generalSettings.toolpost == "oppositeEndWorking2" || generalSettings.toolpost == "oppositeEndWorking1") {
      yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-1});
    } else {
      yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:1});
    }
    yOutput = createVariable({prefix:"Y"}, yFormat);
    xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual" ? -1 : 1});
    xOutput = createVariable({prefix:"X"}, xFormat);
    yOutput.enable(); // required for G12.1
    cOutput.disable();
    polarIsActive = true;
  } else {
    writeBlock(gPolarModal.format(getCode("POLAR_INTERPOLATION_OFF", getSpindle(true))));
    yOutput = createVariable({prefix:"Y"}, yFormat);
    if (!gotYAxis) {
      yOutput.disable();
    }
    cOutput.enable();
    polarIsActive = false;
    writeBlock(getSpindle(true) == SPINDLE_MAIN ? mFormat.format(20) : mFormat.format(79));
  }
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

function onRewindMachine(_a, _b, _c) {
}

function onRapid(_x, _y, _z) {
  debugSectionHeader("onRapid");
  if (machineState.useXZCMode) {
    var start = getCurrentPosition();
    var dxy = getModulus(_x - start.x, _y - start.y);
    if (true) {
      var x = xOutput.format(getModulus(_x, _y));
      var currentC = getCClosest(_x, _y, cOutput.getCurrent());
      var c = cOutput.format(currentC);
      var z = zOutput.format(_z);
      if (pendingRadiusCompensation >= 0) {
        error(localize("Radius compensation mode cannot be changed at rapid traversal."));
        return;
      }
      writeBlock(gMotionModal.format(0), x, z, getParameter("operation-strategy") == "drill" ? "" : c);
      previousABC.setZ(currentC);
      forceFeed();
      return;
    }
  }

  var mainSpindle = (getSpindle(true) == SPINDLE_MAIN);
  var invertRadiusCompensation = (generalSettings.xScale < 0 || generalSettings.zScale < 0) && !(generalSettings.xScale < 0 && generalSettings.zScale < 0);

  /// comp info
  // MAIN SPINDLE
  // Z=POSITIVE X=POSITIVE
  // COMP LEFT = 41 COMP RIGHT = 42
  // Z = NEGATIVE OR X = NEGATIVE
  // COMPLEFT = 42 COMP RIGHT = 41
  // Z = NEG AND X = NEG
  // COMP LEFT = 41 COMP RIGHT = 42

  // SUB SPINDLE
  // Z=POSITIVE X=POSITIVE
  // COMP LEFT = 42 COMP RIGHT = 41
  // Z = NEGATIVE OR X = NEGATIVE
  // COMPLEFT = 41 COMP RIGHT = 42
  // Z = NEG AND X = NEG
  // COMP LEFT = 42 COMP RIGHT = 41

  // TO USE NORMAL LOGIC (WITH GENERAL SETTINGS OVERRIDES ENABLED), UNCOMMENT THE BELOW BLOCK
  // invertRadiusCompensation = false;

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    var useG1 = false;
    var highFeed = machineState.usePolarMode ? toPreciseUnit(1500, MM) : getHighfeedrate(_x);
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      if (useG1) {
        switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          var compCode = (mainSpindle ? (invertRadiusCompensation ? 42 : 41) : (invertRadiusCompensation ? 42 : 41));
          if (generalSettings.compLeft) {
            compCode = generalSettings.compLeft;
          }
          writeBlock(
            gMotionModal.format(1),
            gFormat.format(compCode),
            x, y, z, getFeed(highFeedrate)
          );
          break;
        case RADIUS_COMPENSATION_RIGHT:
          var compCode = (mainSpindle ? (invertRadiusCompensation ? 41 : 42) : (invertRadiusCompensation ? 41 : 42));
          if (generalSettings.compRight) {
            compCode = generalSettings.compRight;
          }
          writeBlock(
            gMotionModal.format(1),
            gFormat.format(compCode),
            x, y, z, getFeed(highFeedrate)
          );
          break;
        default:
          writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, getFeed(highFeedrate));
        }
      } else {
        switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          var compCode = (mainSpindle ? (invertRadiusCompensation ? 42 : 41) : (invertRadiusCompensation ? 42 : 41));
          if (generalSettings.compLeft) {
            compCode = generalSettings.compLeft;
          }
          writeBlock(
            gMotionModal.format(0),
            gFormat.format(compCode),
            x, y, z
          );
          break;
        case RADIUS_COMPENSATION_RIGHT:
          var compCode = (mainSpindle ? (invertRadiusCompensation ? 41 : 42) : (invertRadiusCompensation ? 41 : 42));
          if (generalSettings.compRight) {
            compCode = generalSettings.compRight;
          }
          writeBlock(
            gMotionModal.format(0),
            gFormat.format(compRight),
            x, y, z
          );
          break;
        default:
          writeBlock(gMotionModal.format(0), gFormat.format(40), x, y, z);
        }
      }
    } else {
      if (useG1) {
        // axes are not synchronized
        writeBlock(gMotionModal.format(1), x, machineState.axialCenterDrilling ? "" : y, z, getFeed(highFeedrate));
        resetFeed = false;
      } else {
        if (machineState.usePolarMode) {
          writeBlock(gMotionModal.format(1), x, machineState.axialCenterDrilling ? "" : y, z, getFeed(highFeedrate));
        } else {
          writeBlock(gMotionModal.format(0), x, machineState.axialCenterDrilling ? "" : y, z);
        // forceFeed();
        }
      }
    }
  }
}

/** Returns the U-coordinate along the 2D line for the projection of point p. */
function getLineProjectionU(start, end, p) {
  var ax = p.x - start.x;
  var ay = p.y - start.y;
  var deltax = end.x - start.x;
  var deltay = end.y - start.y;
  var squareModulus = deltax * deltax + deltay * deltay;
  var d = ax * deltax + ay * deltay; // dot
  return (squareModulus > 0) ? d / squareModulus : 0;
}

function onLinear(_x, _y, _z, feed) {
  debugSectionHeader("onLinear");
  if (currentFeedMode == 1 && machineState.axialCenterDrilling && getParameter("operation-strategy") == "drill") {
    if (hasParameter("operation:tool_feedPerRevolution")) {
      feed = getParameter("operation:tool_feedPerRevolution");
    } else {
      error("feed per revolution is not defined");
    }
  }

  if (machineState.useXZCMode) {
    //if (pendingRadiusCompensation >= 0) {
    //  error(subst(localize("Radius compensation is not supported for operation \"%1\". You have to use G112 mode for radius compensation."), getOperationComment()));
    //  return;
    //}
    if (maximumCircularSweep > toRad(179)) {
      error(localize("Maximum circular sweep must be below 179 degrees."));
      return;
    }

    var localTolerance = getTolerance() / 4;

    var startXYZ = getCurrentPosition();
    var startX = getModulus(startXYZ.x, startXYZ.y);
    var startZ = startXYZ.z;
    var startC = cOutput.getCurrent();

    var endXYZ = new Vector(_x, _y, _z);
    var endX = getModulus(endXYZ.x, endXYZ.y);
    var endZ = endXYZ.z;
    // var endC = getCWithinRange(endXYZ.x, endXYZ.y, startC);
    var endC = getCClosest(endXYZ.x, endXYZ.y, startC);

    var currentXYZ = endXYZ; var currentX = endX; var currentZ = endZ; var currentC = endC;
    var centerXYZ = machineConfiguration.getAxisU().getOffset();

    var refined = true;
    var crossingRotary = false;
    forceOptimized = false; // tool tip is provided to DPM calculations

    while (refined) { // stop if we dont refine

      // check if we cross center of rotary axis
      var _start = new Vector(startXYZ.x, startXYZ.y, 0);
      var _current = new Vector(currentXYZ.x, currentXYZ.y, 0);
      var _center = new Vector(centerXYZ.x, centerXYZ.y, 0);

      if ((xFormat.getResultingValue(pointLineDistance(_start, _current, _center)) == 0) &&
        (xFormat.getResultingValue(Vector.diff(_start, _center).length) != 0) &&
        (xFormat.getResultingValue(Vector.diff(_current, _center).length) != 0)) {
        var ratio = Vector.diff(_center, _start).length / Vector.diff(_current, _start).length;
        currentXYZ = centerXYZ;
        currentXYZ.z = startZ + (endZ - startZ) * ratio;
        currentX = getModulus(currentXYZ.x, currentXYZ.y);
        currentZ = currentXYZ.z;
        currentC = startC;
        crossingRotary = true;

      } else { // check if move is out of tolerance
        refined = false;
        while (!refineSegmentXC(startX, startC, currentX, currentC, localTolerance)) { // move is out of tolerance
          refined = true;
          currentXYZ = Vector.lerp(startXYZ, currentXYZ, 0.75);
          currentX = getModulus(currentXYZ.x, currentXYZ.y);
          currentZ = currentXYZ.z;
          // currentC = getCWithinRange(currentXYZ.x, currentXYZ.y, startC);
          currentC = getCClosest(currentXYZ.x, currentXYZ.y, startC);
          if (Vector.diff(startXYZ, currentXYZ).length < 1e-5) { // back to start point, output error
            /*if (forceRewind) {
              break;
            } else*/ {
              warning(localize("Linear move cannot be mapped to rotary XZC motion."));
              break;
            }
          }
        }

      }

      // currentC = getCWithinRange(currentXYZ.x, currentXYZ.y, startC);
      currentC = getCClosest(currentXYZ.x, currentXYZ.y, startC);
      /*if (forceRewind) {
        var rewindC = getCClosest(startXYZ.x, startXYZ.y, currentC);
        xOutput.reset(); // force X for repositioning
        rewindTable(startXYZ, currentZ, rewindC, feed, true);
        previousABC.setZ(rewindC);
      }*/
      var x = xOutput.format(currentX);
      var c = cOutput.format(currentC);
      var z = zOutput.format(currentZ);
      var actualFeed = getMultiaxisFeed(currentXYZ.x, currentXYZ.y, currentXYZ.z, 0, 0, currentC, feed);
      if (x || c || z) {
        writeBlock(gMotionModal.format(1), x, c, z, getFeed(actualFeed.frn));
      }
      setCurrentPosition(currentXYZ);
      previousABC.setZ(currentC);
      if (crossingRotary) {
        writeBlock(gMotionModal.format(1), cOutput.format(endC), getFeed(feed)); // rotate at X0 with endC
        previousABC.setZ(endC);
        forceFeed();
      }
      startX = currentX; startZ = currentZ; startC = crossingRotary ? endC : currentC; startXYZ = currentXYZ; // loop start point
      currentX = endX; currentZ = endZ; currentC = endC; currentXYZ = endXYZ; // loop end point
      crossingRotary = false;
    }
    forceOptimized = undefined;
    return;
  }

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
  //xOutput = createVariable({prefix:"X"}, machines.l.xFormatMilling);
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = getFeed(feed);

  var mainSpindle = (getSpindle(true) == SPINDLE_MAIN);
  var invertRadiusCompensation = (generalSettings.xScale < 0 || generalSettings.zScale < 0) && !(generalSettings.xScale < 0 && generalSettings.zScale < 0);

  /// comp info
  // MAIN SPINDLE
  // Z=POSITIVE X=POSITIVE
  // COMP LEFT = 41 COMP RIGHT = 42
  // Z = NEGATIVE OR X = NEGATIVE
  // COMPLEFT = 42 COMP RIGHT = 41
  // Z = NEG AND X = NEG
  // COMP LEFT = 41 COMP RIGHT = 42

  // SUB SPINDLE
  // Z=POSITIVE X=POSITIVE
  // COMP LEFT = 42 COMP RIGHT = 41
  // Z = NEGATIVE OR X = NEGATIVE
  // COMPLEFT = 41 COMP RIGHT = 42
  // Z = NEG AND X = NEG
  // COMP LEFT = 42 COMP RIGHT = 41

  // TO USE NORMAL LOGIC (WITH GENERAL SETTINGS OVERRIDES ENABLED), UNCOMMENT THE BELOW BLOCK
  // invertRadiusCompensation = false;

  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {

      pendingRadiusCompensation = -1;
      if (machineState.isTurningOperation) {
        writeBlock(gPlaneModal.format(18));
      } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
        // writeBlock(gPlaneModal.format(getG17Code()));
      } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
        //writeBlock(gPlaneModal.format(19));
      }
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        var compCode = (mainSpindle ? (invertRadiusCompensation ? 42 : 41) : (invertRadiusCompensation ? 42 : 41));
        if (generalSettings.compLeft) {
          compCode = generalSettings.compLeft;
        }
        if (machineState.isTurningOperation) {
          writeBlock(gPlaneModal.format(18));
        } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
          writeBlock(gPlaneModal.format(getG17Code()));
        } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
          if (generalSettings.toolpost == "gangBaxisDriven") {
            writeBlock(gPlaneModal.format(getG17Code()));
          } else {
            writeBlock(gPlaneModal.format(19));
          }
        } else {
          writeBlock(gPlaneModal.format(getG17Code()));
        }
        writeBlock(
          gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1),
          gFormat.format(compCode),
          x, y, z, f
        );
        break;
      case RADIUS_COMPENSATION_RIGHT:
        var compCode = (mainSpindle ? (invertRadiusCompensation ? 41 : 42) : (invertRadiusCompensation ? 41 : 42));
        if (generalSettings.compRight) {
          compCode = generalSettings.compRight;
        }
        if (machineState.isTurningOperation) {
          writeBlock(gPlaneModal.format(18));
        } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
          writeBlock(gPlaneModal.format(getG17Code()));
        } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
          if (generalSettings.toolpost == "gangBaxisDriven") {
            writeBlock(gPlaneModal.format(getG17Code()));
          } else {
            writeBlock(gPlaneModal.format(19));
          }
        } else {
          writeBlock(gPlaneModal.format(getG17Code()));
        }
        writeBlock(
          gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1),
          gFormat.format(compCode),
          x, y, z, f
        );
        break;
      default:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(40), x, y, z, f);
      }
    } else {
      if (machineState.isTurningOperation) {
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), x, z, f);
      } else {
        if (generalSettings.toolpost == "gangBaxisDriven") {
          writeBlock(gPlaneModal.format(getG17Code()));
        }
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), x, y, z, f);
      }
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {

  if (!currentSection.isOptimizedForMachine()) {
    error(localize("Multi-axis motion is not supported for XZC mode."));
    return;
  }
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
    // axes are not synchronized
    if (generalSettings.newGen && generalSettings.toolpost == "gangBaxisDriven") {
      writeBlock(gMotionModal.format(1), x, y, z, a, b, c);
    } else {
      writeBlock(gMotionModal.format(0), x, y, z, c);
    }
    forceFeed();
  }
  previousABC = new Vector(_a, _b, _c);
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("Multi-axis motion is not supported for XZC mode."));
    return;
  }
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
  //var actualFeed = getMultiaxisFeed(_x, _y, _z, _a, _b, _c, feed);
  //var f = feedOutput.format(feed);

  //*************** WE SHOULD BE USING MULTI AXIS FEEDRATE HERE ***************
  //  var f = getFeed(feed);
  var f = feedOutput.format(getMultiaxisFeed(_x, _y, _z, _a, _b, _c, feed).frn);

  if (x || y || z || a || b || c) {
    if (generalSettings.toolpost == "gangBaxisDriven" && !generalSettings.newGen) {
      if (!generalSettings.newGen && b && (hasParameter("operation:isMultiAxisStrategy") && (getParameter("operation:isMultiAxisStrategy") != 0))) {
        error(localize("Toolpath is 5 axis simultaneous and cannot run on this machine.  Please modify the toolpath '" + getParameter("operation-comment") + "'"));
      } else if (generalSettings.newGen) {
        writeBlock(gMotionModal.format(1), x, y, z, a, b, c, f);
      }
      writeBlock(gMotionModal.format(1), x, y, z, a, c, f);
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, c, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
  previousABC = new Vector(_a, _b, _c);
}

// Start of multi-axis feedrate logic
/***** Be sure to add 'useInverseTime' to post properties if necessary. *****/
/***** 'inverseTimeOutput' should be defined if Inverse Time feedrates are supported. *****/
/***** 'previousABC' can be added throughout to maintain previous rotary positions. Required for Mill/Turn machines. *****/
/***** 'headOffset' should be defined when a head rotary axis is defined. *****/
/***** The feedrate mode must be included in motion block output (linear, circular, etc.) for Inverse Time feedrate support. *****/
var dpmBPW = 1.0; // ratio of rotary accuracy to linear accuracy for DPM calculations
var inverseTimeUnits = 1.0; // 1.0 = minutes, 60.0 = seconds
var maxInverseTime = 45000; // maximum value to output for Inverse Time feeds
var maxDPM = 99999; // maximum value to output for DPM feeds
var useInverseTimeFeed = false; // use DPM feeds
var previousDPMFeed = 0; // previously output DPM feed
var dpmFeedToler = 0.5; // tolerance to determine when the DPM feed has changed
var previousABC = new Vector(0, 0, 0); // previous ABC position if maintained in post, don't define if not used
var previousABCy;
var forceOptimized = undefined; // used to override optimized-for-angles points (XZC-mode)

/** Calculate the multi-axis feedrate number. */
function getMultiaxisFeed(_x, _y, _z, _a, _b, _c, feed) {
  var f = {frn:0, fmode:0};
  if (feed <= 0) {
    error(localize("Feedrate is less than or equal to 0."));
    return f;
  }

  var length = getMoveLength(_x, _y, _z, _a, _b, _c);

  if (useInverseTimeFeed) { // inverse time
    f.frn = getInverseTime(length.tool, feed);
    f.fmode = 93;
    feedOutput.reset();
  } else { // degrees per minute
    f.frn = getFeedDPM(length, feed);
    f.fmode = 94;
  }
  return f;
}

/** Returns point optimization mode. */
function getOptimizedMode() {
  if (forceOptimized != undefined) {
    return forceOptimized;
  }
  // return (currentSection.getOptimizedTCPMode() != 0); // TAG:doesn't return correct value
  return true; // always return false for non-TCP based heads
}

/** Calculate the DPM feedrate number. */
function getFeedDPM(_moveLength, _feed) {
  if ((_feed == 0) || (_moveLength.tool < 0.0001) || (toDeg(_moveLength.abcLength) < 0.0005)) {
    previousDPMFeed = 0;
    return _feed;
  }
  var moveTime = _moveLength.tool / _feed;
  if (moveTime == 0) {
    previousDPMFeed = 0;
    return _feed;
  }

  var dpmFeed;
  var tcp = !getOptimizedMode() && (forceOptimized == undefined);   // set to false for rotary heads
  if (tcp) { // TCP mode is supported, output feed as FPM
    dpmFeed = _feed;
  } else if (false) { // standard DPM
  } else if (true) { // combination FPM/DPM
    var length = Math.sqrt(Math.pow(_moveLength.xyzLength, 2.0) + Math.pow((toDeg(_moveLength.abcLength) * dpmBPW), 2.0));
    dpmFeed = Math.min((length / moveTime), maxDPM);
    if (Math.abs(dpmFeed - previousDPMFeed) < dpmFeedToler) {
      dpmFeed = previousDPMFeed;
    }
  } else { // machine specific calculation
  }
  previousDPMFeed = dpmFeed;
  return dpmFeed;
}

/** Calculate the Inverse time feedrate number. */
function getInverseTime(_length, _feed) {
  var inverseTime;
  if (_length < 1.e-6) { // tool doesn't move
    if (typeof maxInverseTime === "number") {
      inverseTime = maxInverseTime;
    } else {
      inverseTime = 999999;
    }
  } else {
    inverseTime = _feed / _length / inverseTimeUnits;
    if (typeof maxInverseTime === "number") {
      if (inverseTime > maxInverseTime) {
        inverseTime = maxInverseTime;
      }
    }
  }
  return inverseTime;
}

/** Calculate radius for each rotary axis. */
function getRotaryRadii(startTool, endTool, startABC, endABC) {
  var radii = new Vector(0, 0, 0);
  var startRadius;
  var endRadius;
  var axis = new Array(machineConfiguration.getAxisU(), machineConfiguration.getAxisV(), machineConfiguration.getAxisW());
  for (var i = 0; i < 3; ++i) {
    if (axis[i].isEnabled()) {
      var startRadius = getRotaryRadius(axis[i], startTool, startABC);
      var endRadius = getRotaryRadius(axis[i], endTool, endABC);
      radii.setCoordinate(axis[i].getCoordinate(), Math.max(startRadius, endRadius));
    }
  }
  return radii;
}

/** Calculate the distance of the tool position to the center of a rotary axis. */
function getRotaryRadius(axis, toolPosition, abc) {
  if (!axis.isEnabled()) {
    return 0;
  }

  var direction = axis.getEffectiveAxis();
  var normal = direction.getNormalized();
  // calculate the rotary center based on head/table
  var center;
  var radius;
  if (axis.isHead()) {
    var pivot;
    if (typeof headOffset === "number") {
      pivot = headOffset;
    } else {
      pivot = tool.getBodyLength();
    }
    if (axis.getCoordinate() == machineConfiguration.getAxisU().getCoordinate()) { // rider
      center = Vector.sum(toolPosition, Vector.product(machineConfiguration.getDirection(abc), pivot));
      center = Vector.sum(center, axis.getOffset());
      radius = Vector.diff(toolPosition, center).length;
    } else { // carrier
      var angle = abc.getCoordinate(machineConfiguration.getAxisU().getCoordinate());
      radius = Math.abs(pivot * Math.sin(angle));
      radius += axis.getOffset().length;
    }
  } else {
    center = axis.getOffset();
    var d1 = toolPosition.x - center.x;
    var d2 = toolPosition.y - center.y;
    var d3 = toolPosition.z - center.z;
    var radius = Math.sqrt(
      Math.pow((d1 * normal.y) - (d2 * normal.x), 2.0) +
      Math.pow((d2 * normal.z) - (d3 * normal.y), 2.0) +
      Math.pow((d3 * normal.x) - (d1 * normal.z), 2.0)
    );
  }
  return radius;
}

/** Calculate the linear distance based on the rotation of a rotary axis. */
function getRadialDistance(radius, startABC, endABC) {
  // calculate length of radial move
  var delta = Math.abs(endABC - startABC);
  if (delta > Math.PI) {
    delta = 2 * Math.PI - delta;
  }
  var radialLength = (2 * Math.PI * radius) * (delta / (2 * Math.PI));
  return radialLength;
}

/** Calculate tooltip, XYZ, and rotary move lengths. */
function getMoveLength(_x, _y, _z, _a, _b, _c) {
  // get starting and ending positions
  var moveLength = {};
  var startTool;
  var endTool;
  var startXYZ;
  var endXYZ;
  var startABC;
  if (typeof previousABC !== "undefined") {
    startABC = new Vector(previousABC.x, previousABC.y, previousABC.z);
  } else {
    startABC = getCurrentDirection();
  }
  var endABC = new Vector(_a, _b, _c);

  if (!getOptimizedMode()) { // calculate XYZ from tool tip
    startTool = getCurrentPosition();
    endTool = new Vector(_x, _y, _z);
    startXYZ = startTool;
    endXYZ = endTool;

    // adjust points for tables
    if (!machineConfiguration.getTableABC(startABC).isZero() || !machineConfiguration.getTableABC(endABC).isZero()) {
      startXYZ = machineConfiguration.getOrientation(machineConfiguration.getTableABC(startABC)).getTransposed().multiply(startXYZ);
      endXYZ = machineConfiguration.getOrientation(machineConfiguration.getTableABC(endABC)).getTransposed().multiply(endXYZ);
    }

    // adjust points for heads
    if (machineConfiguration.getAxisU().isEnabled() && machineConfiguration.getAxisU().isHead()) {
      if (typeof getOptimizedHeads === "function") { // use post processor function to adjust heads
        startXYZ = getOptimizedHeads(startXYZ.x, startXYZ.y, startXYZ.z, startABC.x, startABC.y, startABC.z);
        endXYZ = getOptimizedHeads(endXYZ.x, endXYZ.y, endXYZ.z, endABC.x, endABC.y, endABC.z);
      } else { // guess at head adjustments
        var startDisplacement = machineConfiguration.getDirection(startABC);
        startDisplacement.multiply(headOffset);
        var endDisplacement = machineConfiguration.getDirection(endABC);
        endDisplacement.multiply(headOffset);
        startXYZ = Vector.sum(startTool, startDisplacement);
        endXYZ = Vector.sum(endTool, endDisplacement);
      }
    }
  } else { // calculate tool tip from XYZ, heads are always programmed in TCP mode, so not handled here
    startXYZ = getCurrentPosition();
    endXYZ = new Vector(_x, _y, _z);
    startTool = machineConfiguration.getOrientation(machineConfiguration.getTableABC(startABC)).multiply(startXYZ);
    endTool = machineConfiguration.getOrientation(machineConfiguration.getTableABC(endABC)).multiply(endXYZ);
  }

  // calculate axes movements
  moveLength.xyz = Vector.diff(endXYZ, startXYZ).abs;
  moveLength.xyzLength = moveLength.xyz.length;
  moveLength.abc = Vector.diff(endABC, startABC).abs;
  for (var i = 0; i < 3; ++i) {
    if (moveLength.abc.getCoordinate(i) > Math.PI) {
      moveLength.abc.setCoordinate(i, 2 * Math.PI - moveLength.abc.getCoordinate(i));
    }
  }
  moveLength.abcLength = moveLength.abc.length;

  // calculate radii
  moveLength.radius = getRotaryRadii(startTool, endTool, startABC, endABC);

  // calculate the radial portion of the tool tip movement
  var radialLength = Math.sqrt(
    Math.pow(getRadialDistance(moveLength.radius.x, startABC.x, endABC.x), 2.0) +
    Math.pow(getRadialDistance(moveLength.radius.y, startABC.y, endABC.y), 2.0) +
    Math.pow(getRadialDistance(moveLength.radius.z, startABC.z, endABC.z), 2.0)
  );

  // calculate the tool tip move length
  // tool tip distance is the move distance based on a combination of linear and rotary axes movement
  moveLength.tool = moveLength.xyzLength + radialLength;

  return moveLength;
}
// End of multi-axis feedrate logic

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (getCircularPlane() == PLANE_YZ) {
    if (generalSettings.zScale == 1) {
      var directionCode = (getSpindle(true) == SPINDLE_SUB) ? (clockwise ? 2 : 3) : (clockwise ? 2 : 3);
    } else {
      var directionCode = (getSpindle(true) == SPINDLE_SUB) ? (clockwise ? 2 : 3) : (clockwise ? 2 : 3);
    }
  } else
    if (generalSettings.zScale == 1) {
      var directionCode = (getSpindle(true) == SPINDLE_SUB) ? (clockwise ? 3 : 2) : (clockwise ? 3 : 2);
    } else {

      var directionCode = (getSpindle(true) == SPINDLE_SUB) ? (clockwise ? 3 : 2) : (clockwise ? 3 : 2);
    }

  if (machineState.useXZCMode) {
    switch (getCircularPlane()) {
    case PLANE_ZX:
      if (!isSpiral()) {
        var c = getCClosest(x, y, cOutput.getCurrent());
        if (!cFormat.areDifferent(c, cOutput.getCurrent())) {
          validate(getCircularSweep() < Math.PI, localize("Circular sweep exceeds limit."));
          var start = getCurrentPosition();
          writeBlock(gPlaneModal.format(18), gMotionModal.format(directionCode), xOutput.format(getModulus(x, y)), cOutput.format(c), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
          previousABC.setZ(c);
          return;
        }
      }
      break;
    case PLANE_XY:
      var d2 = center.x * center.x + center.y * center.y;
      if (d2 < 1e-18) { // center is on rotary axis
        var c = getCClosest(x, y, cOutput.getCurrent(), clockwise);
        writeBlock(gMotionModal.format(1), xOutput.format(getModulus(x, y)), cOutput.format(c), zOutput.format(z), getFeed(feed));
        previousABC.setZ(c);
        return;
      }
      break;
    }

    linearize(getTolerance());
    return;
  }

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
    if (properties.useRadius || isHelical()) { // radius mode does not support full arcs
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(getG17Code()), gMotionModal.format(directionCode), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), getFeed(feed));
      break;
    case PLANE_ZX:
      if (machineState.usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(directionCode), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    case PLANE_YZ:
      if (machineState.usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(directionCode), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else if (!properties.useRadius) {

    if (isHelical() && ((getCircularSweep() < toRad(30)) || (getHelicalPitch() > 10))) { // avoid G112 issue
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(getG17Code()));
      writeBlock(gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), getFeed(feed));
      break;
    case PLANE_ZX:
      if (machineState.usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18));
      writeBlock(gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    case PLANE_YZ:
      if (machineState.usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19));
      writeBlock(gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else { // use radius mode
    //if (generalSettings.toolpost == "subCrossWorking" || generalSettings.toolpost == "backToolPostStatic"){
    //  linearize(tolerance);
    //  return;
    //}
    if (isHelical() && ((getCircularSweep() < toRad(30)) || (getHelicalPitch() > 10))) {
      linearize(tolerance);
      return;
    }
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(getG17Code()));
      writeBlock(gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_ZX:
      if (machineState.usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18));
      writeBlock(gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_YZ:
      if (machineState.usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19));
      writeBlock(gMotionModal.format(directionCode), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  }

}

function onCycle() {
  debugSectionHeader("onCycle");
  if (!properties.useCycles && tapping) {
    startSpindle(false, false);
  }
}

function getCommonCycle(x, y, z, r, includeRcode) {

  // R-value is incremental position from current position
  var raptoS = "";
  if ((r !== undefined) && includeRcode) {
    raptoS = "R" + spatialFormat.format(r);
  }

  if (machineState.useXZCMode) {
    cOutput.reset();
    return [xOutput.format(getModulus(x, y)), cOutput.format(getCClosest(x, y, cOutput.getCurrent(), false)),
      zOutput.format(z),
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
      writeBlock(gMotionModal.format(0), zOutput.format(clearance));
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
  debugSectionHeader("onCyclePoint");
  //if (!properties.useCycles|| currentSection.isMultiAxis()) {
  //      expandCyclePoint(x, y, z);
  //  return;
  //}
  var plane = gPlaneModal.getCurrent();

  var localZOutput = zOutput;
  var cycleAxis = currentSection.workPlane.forward;
  var found = false;

  if (!found) {
    if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1)) ||
        isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
      plane = 17; // XY plane
      localZOutput = zOutput;
    } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
      plane = 19; // YZ plane
      localZOutput = xOutput;
    } else if (gotBAxis && !bAxisIsManual) {
      plane = 19;  // use G19 for B-axis when outside major plane
      localZoutput = xOutput;
    } else if (gotBAxis) { // manual B-axis
      if (isSameDirection(machineConfiguration.getSpindleAxis(), new Vector(0, 0, 1)) ||
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
  if (generalSettings.toolpost == "gangBaxisDriven") {
    plane = 18;
  }
  if (generalSettings.toolpost == "gangCrossWorking") {
    plane = 19;
  }

  switch (cycleType) {
  case "thread-turning":
    if (useSimpleThread ||
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
        var firstDepthOfCut = threadHeight / getParameter("operation:numberOfStepdowns");

        // first G76 block
        var repeatPass = hasParameter("operation:nullPass") ? getParameter("operation:nullPass") : 0;
        var chamferWidth = 10; // Pullout-width is 1*thread-lead in 1/10's;
        var materialAllowance = 0; // Material allowance for finishing pass
        var cuttingAngle = 60; // Angle is not stored with tool. toDeg(tool.getTaperAngle());
        if (hasParameter("operation:infeedAngle")) {
          cuttingAngle = getParameter("operation:infeedAngle");
        }
        var pcode = repeatPass * 10000 + chamferWidth * 100 + cuttingAngle;
        gCycleModal.reset();
        writeBlock(
          gCycleModal.format(76),
          threadP1Output.format(pcode),
          threadQOutput.format(firstDepthOfCut),
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
  if (!machineState.axialCenterDrilling && !machineState.isTurningOperation) {
    lockCode = mFormat.format(getCode("LOCK_MULTI_AXIS", getSpindle(true)));
  }

  var rapto = 0;
  if (isFirstCyclePoint()) { // first cycle point
    rapto = (getSpindle(true) == SPINDLE_SUB) ? cycle.clearance - cycle.retract : cycle.retract - cycle.clearance;
    var F = (currentFeedMode == 1 ? cycle.feedrate / spindleSpeed : cycle.feedrate);
    var P = !cycle.dwell ? 0 : clamp(1, cycle.dwell * 1000, 99999999); // in milliseconds

    switch (cycleType) {
    case "drilling":
      // writeCycleClearance(plane, cycle.clearance);
      // localZOutput.reset();
      if (plane == 19) {
        writeBlock(
          gCycleModal.format(87),
          machineState.useXZCMode ? xOutput.format(getModulus(x, y)) : xOutput.format(x),
          feedOutput.format(F)
        );

      } else {
        writeBlock(
          gCycleModal.format(83),
          zOutput.format(z),
          feedOutput.format(F)
        );
      }
      break;
    case "chip-breaking":
    case "deep-drilling":
      writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      if (plane == 19) {
        writeBlock(
          gCycleModal.format(87),
          machineState.useXZCMode ? xOutput.format(getModulus(x, y)) : xOutput.format(x),
          conditional(cycle.incrementalDepth > 0, qOutput.format(cycle.incrementalDepth)),
          feedOutput.format(F)
        );

      } else {
        writeBlock(
          gCycleModal.format(83),
          zOutput.format(z),
          conditional(cycle.incrementalDepth > 0, qOutput.format(cycle.incrementalDepth)),
          feedOutput.format(F)
        );
      }
      break;
    case "tapping":
    case "right-tapping":
    case "left-tapping":
      // writeCycleClearance(plane, cycle.clearance);
      localZOutput.reset();
      //writeBlock ("tooltype is " + getParameter("operation:tool_hand"))
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      startSpindle(true, false);
      reverseTap = tool.type == TOOL_TAP_LEFT_HAND;
      //if (reverseTap) {
      //writeBlock(mFormat.format(176));
      //}
      if (plane == 19) {
        writeBlock(
          gCycleModal.format(88),
          machineState.useXZCMode ? xOutput.format(getModulus(x, y)) : xOutput.format(x),
          "S" + spindleSpeed,
          conditional(P > 0, pOutput.format(P)),
          getFeed(F),
          reverseTap ? "D" + getEncoder() * -1 : "D" + getEncoder(),
          ",R1"
          //lockCode
        );

      } else {
        writeBlock(
          gCycleModal.format(84),
          zOutput.format(z),
          "S" + spindleSpeed,
          conditional(P > 0, pOutput.format(P)),
          getFeed(cycle.feedrate),
          reverseTap ? "D" + getEncoder() * -1 : "D" + getEncoder(),
          ",R1"
          //lockCode
        );
      }

      break;
    case "tapping-with-chip-breaking":
      localZOutput.reset();
      //writeBlock ("tooltype is " + getParameter("operation:tool_hand"))
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      startSpindle(true, false);
      reverseTap = tool.type == TOOL_TAP_LEFT_HAND;
      //if (reverseTap) {
      //writeBlock(mFormat.format(176));
      //}

      var cycleStep = cycle.incrementalDepth;
      if (plane == 19) {
        var totalDepth = machineState.useXZCMode ? getModulus(x, y) : x;
        writeBlock(
          gCycleModal.format(88),
          machineState.useXZCMode ? xOutput.format(getModulus(x, y)) : xOutput.format(x),
          "S" + spindleSpeed,
          conditional(P > 0, pOutput.format(P)),
          pitchOutput.format(F),
          reverseTap ? "D" + getEncoder() * -1 : "D" + getEncoder(),
          ",R1"
          //lockCode
        );
      } else {
        var totalDepth = z;
        cycleStep = cycle.incrementalDepth;
        writeBlock(
          gCycleModal.format(84),
          zOutput.format(cycle.incrementalDepth * -1),
          "S" + spindleSpeed,
          conditional(P > 0, pOutput.format(P)),
          pitchOutput.format(F),
          reverseTap ? "D" + getEncoder() * -1 : "D" + getEncoder(),
          ",R1"
          //lockCode
        );
        totalDepth *= -1;
      }

      while (totalDepth > cycle.incrementalDepth) {
        if (cycle.incrementalDepth < totalDepth) {

          writeBlock(plane == 19 ? xOutput.format(cycle.incrementalDepth) : zOutput.format(cycle.incrementalDepth * -1));
          cycle.incrementalDepth += cycleStep;
          zOutput.reset();
        }
        if (totalDepth < cycle.incrementalDepth) {
          writeBlock(plane == 19 ? xOutput.format(totalDepth) : zOutput.format(totalDepth));
          zOutput.reset();
        }
        //cycle.depth = (cycle.depth - cycle.incrementalDepth)
      }

      break;

    case "boring":
      expandCyclePoint(x, y, z);
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
      writeBlock(getCommonCycle(x, y, z, rapto, false), conditional(step > 0, qOutput.format(step)));
    }
  }
}

function onCycleEnd() {
  debugSectionHeader("onCycleEnd");
  if (!cycleExpanded) {
    writeBlock(gCycleModal.format(80));
    gMotionModal.reset();
  }
}

function onPassThrough(text) {
  writeBlock(text);
}
let closedSection = false;
function onParameter(name, value) {
  var invalid = false;
  switch (name) {
  case "action":
    if (String(value).toUpperCase() == "USEXZCMODE") {
      forceXZCMode = true;
      forcePolarMode = false;
    } else if (String(value).toUpperCase() == "USEPOLARMODE") {
      forcePolarMode = true;
      forceXZCMode = false;
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

function isSpindleSpeedDifferent() {
  if (isFirstSection()) {
    return true;
  }
  if (getPreviousSection().getTool().clockwise != tool.clockwise) {
    return true;
  }
  if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
    if ((getPreviousSection().getTool().getSpindleMode() != SPINDLE_CONSTANT_SURFACE_SPEED) ||
      rpmFormat.areDifferent(getPreviousSection().getTool().surfaceSpeed, tool.surfaceSpeed)) {
      return true;
    }
  } else {
    if ((getPreviousSection().getTool().getSpindleMode() != SPINDLE_CONSTANT_SPINDLE_SPEED) ||
      rpmFormat.areDifferent(getPreviousSection().getTool().spindleRPM, spindleSpeed)) {
      return true;
    }
  }
  return false;
}

function onSpindleSpeed(spindleSpeed) {
  if (rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent())) {
    writeBlock(sOutput.format(spindleSpeed));
  }
}

function startSpindle(tappingMode, forceRPMMode, initialPosition) {
  debugSectionHeader("startSpindle");
  var spindleDir;
  var _spindleSpeed;
  var spindleMode;
  gSpindleModeModal.reset();

  if ((getSpindle(true) == SPINDLE_SUB) && !gotSecondarySpindle) {
    error(localize("Secondary spindle is not available."));
    return;
  }

  if (tappingMode) {
    spindleDir = mFormat.format(getCode("RIGID_TAPPING", getSpindle(false)));
  } else {
    spindleDir = mFormat.format(tool.clockwise ? getCode("START_SPINDLE_CW", getSpindle(false)) : getCode("START_SPINDLE_CCW", getSpindle(false)));
  }

  if (!tapping) {
    var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
    if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      _spindleSpeed = tool.surfaceSpeed * ((unit == MM) ? 1 / 1000.0 : 1 / 12.0);
      if (forceRPMMode) { // RPM mode is forced until move to initial position
        _spindleSpeed = Math.min((_spindleSpeed * ((unit == MM) ? 1000.0 : 12.0) / (Math.PI * Math.abs(initialPosition.x * 2))), maximumSpindleSpeed);
        spindleMode = getCode("CONSTANT_SURFACE_SPEED_OFF", getSpindle(false));
      } else {
        spindleMode = getCode("CONSTANT_SURFACE_SPEED_ON", getSpindle(false));
      }
    } else {
      _spindleSpeed = spindleSpeed;
      spindleMode = getCode("CONSTANT_SURFACE_SPEED_OFF", getSpindle(false));
    }
    writeBlock(gFormat.format(50), sOutput.format(properties.maximumSpindleSpeed));
    writeBlock(gSpindleModeModal.format(spindleMode), sOutput.format(_spindleSpeed));
    // wait for spindle here if required
  }
}

function onCommand(command) {
  switch (command) {
  case COMMAND_LOCK_MULTI_AXIS:
    writeBlock(cAxisBrakeModal.format(getCode("LOCK_MULTI_AXIS", getSpindle(true))));
    break;
  case COMMAND_UNLOCK_MULTI_AXIS:
    writeBlock(cAxisBrakeModal.format(getCode("UNLOCK_MULTI_AXIS", getSpindle(true))));
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
    break;
  case COMMAND_OPTIONAL_STOP:
    writeBlock(mFormat.format(1));
    break;
  case COMMAND_END:
    writeBlock(mFormat.format(2));
    break;
  case COMMAND_STOP_SPINDLE:
    if (properties.leaveSpindleRunning) {
      if (machineState.isTurningOperation) {
        writeBlock("(" +
          mFormat.format(getCode("STOP_SPINDLE", activeSpindle)) + ")");
        sOutput.reset();
      } else {
        writeBlock(
          mFormat.format(getCode("STOP_SPINDLE", activeSpindle)));
        sOutput.reset();
      }
    } else {
      writeBlock(
        mFormat.format(getCode("STOP_SPINDLE", activeSpindle)));
      sOutput.reset();
    }
    break;
  case COMMAND_ORIENTATE_SPINDLE:
    if (machineState.isTurningOperation || machineState.axialCenterDrilling) {
      writeBlock(mFormat.format(getCode("ORIENT_SPINDLE", getSpindle(true))));
    } else {
      error(localize("Spindle orientation is not supported for live tooling."));
      return;
    }
    break;
  case COMMAND_SPINDLE_CLOCKWISE:
    writeBlock(mFormat.format(getCode("START_SPINDLE_CW", getSpindle(false))),
      pOutput.format(getCode("SELECT_SPINDLE", getSpindle(false)))
    );
    break;
  case COMMAND_SPINDLE_COUNTERCLOCKWISE:
    writeBlock(mFormat.format(getCode("START_SPINDLE_CCW", getSpindle(false))),
      pOutput.format(getCode("SELECT_SPINDLE", getSpindle(false)))
    );
    break;
  default:
    onUnsupportedCommand(command);
  }
}

function getG17Code() {
  return 17;

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
    sOutput.reset();
    pOutput.reset();
    qOutput.reset();
    rOutput.reset();
    threadP1Output.reset();
    threadP2Output.reset();
    threadQOutput.reset();
    threadROutput.reset();

    if (machineState.usePolarMode) {
      setPolarMode(false); // disable polar interpolation mode
      writeBlock(gPlaneModal.format(18));
    }

    // cancel SFM mode to preserve spindle speed
    if ((tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
      writeBlock(gFormat.format(97));
    }
    if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      if (generalSettings.fluctuation) {
        writeBlock(generalSettings.fluctuation.on);
      }
    }

    if (!GroupedbAxis) {
      if (gotBAxis && generalSettings.toolpost == "gangBaxisDriven") {
        cancelWorkPlane();
      }
    }
    if (generalSettings.toolpost == "gangBaxisDriven" && !GroupedbAxis) {
      writeBlock(gMotionModal.format(40), generalSettings.safetyVal + "+" + xFormat.format(Math.abs(tool.diameter + 1) * -1) + "T0");
    } else {
      writeBlock(gMotionModal.format(40), generalSettings.safetyVal, generalSettings.toolpost == "gangBaxisDriven" ? "+" + Math.abs(tool.diameter + 1) : "", "T0");
    }
    forceXZCMode = false;
    forcePolarMode = false;
    partCutoff = false;
    tooloffsetOutput = false;
    if (properties.useG50OnGang && generalSettings.g50Offset) {
      writeBlock(gFormat.format(50), wOutput.format(generalSettings.g50Offset * -1));
    }
    onCommand(COMMAND_STOP_SPINDLE);

    forceAny();
    shouldRedirect = false;
    if (properties.subroutineAll) {
      writeBlock(mFormat.format(99));
    }
  }
}

const counter = 0;
function onSectionEnd() {
  debugSectionHeader("onSectionEnd");

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
    pOutput.reset();
    qOutput.reset();
    rOutput.reset();
    threadP1Output.reset();
    threadP2Output.reset();
    threadQOutput.reset();
    threadROutput.reset();

    gPlaneModal.reset();
    if (machineState.usePolarMode) {
      const currentPosition = getCurrentPosition();
      if (!generalSettings.toolpost == "backToolPostStatic" || generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual") {
        writeBlock(gMotionModal.format(machineState.usePolarMode ? 1 : 0), zOutput.format(currentPosition.z + tool.diameter / 2));
        setPolarMode(false); // disable polar interpolation mode
        writeBlock(gPlaneModal.format(18));
      } else {
        setPolarMode(false); // disable polar interpolation mode
        writeBlock(gPlaneModal.format(18));
        writeBlock(gMotionModal.format(0), generalSettings.safetyVal);
      }
    }
    if (generalSettings.toolpost == "oppositeEndWorking1" || generalSettings.toolpost == "oppositeEndWorking2") {
      if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
        writeBlock(gMotionModal.format(0), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1));
      } else {
        if (currentSection.isMultiAxis()) {
          writeBlock(gMotionModal.format(0), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1));
        }
      }
    } else if (generalSettings.toolpost == "subCrossWorking") {
      writeBlock(gMotionModal.format(0), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1));
    } else if (generalSettings.toolpost == "backToolPostStatic") {
      if (!machineState.usePolarMode) {
        if (currentSection.isMultiAxis()) {
          writeBlock(gMotionModal.format(0), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1));
        } else {
          if ((getParameter("operation-strategy") != "drill")) {
            writeBlock(gMotionModal.format(0), generalSettings.safetyVal);
          }
        }
      }
    }

    // cancel SFM mode to preserve spindle speed
    if ((tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
      writeBlock(gFormat.format(97));
    }
    if (tool.getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      if (generalSettings.fluctuation) {
        writeBlock(generalSettings.fluctuation.on);
      }
    }

    if (gotBAxis && (generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual")) {
      cancelWorkPlane();
    }
    if (generalSettings.toolpost == "backToolPostTurning") {
      writeBlock(gFormat.format(0), generalSettings.safetyVal);
    }

    if (generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual") {
      if (machineState.usePolarMode) {
        if (!generalSettings.newGen) {
          writeBlock(mFormat.format(211), "Y1");
          writeBlock(gWCSModal.format(901));
        }
        writeBlock(gMotionModal.format(40), "X#100450+" + xyzFormat.format(tool.diameter + 1) + "T0");
      } else {
        if (generalSettings.newGen) {
          writeBlock(gMotionModal.format(40), "X#100450+" + xyzFormat.format(tool.diameter * 2 + 1) + "T0");
        } else {
          writeBlock(gMotionModal.format(40), generalSettings.safetyVal + "+" + xyzFormat.format(tool.diameter + 1) + "T0");
        }
      }
    } else {
      if (tool.number >= 31 && tool.number <= 39) {
        if (currentSection.getType() == TYPE_MILLING && !generalSettings.toolpost == "backToolPostStatic") {
          if (!getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
            writeBlock(gMotionModal.format(40), generalSettings.safetyVal + "T0");
          } else {
            writeBlock(gMotionModal.format(40), "Z" + (-1 - tool.diameter / 2) + "T0");
          }

        } else {
          if (generalSettings.toolpost == "backToolPostStatic") {
            if (!getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {

              if (currentSection.isMultiAxis()) {
                writeBlock(gMotionModal.format(0), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + "T0");
              } else {
                writeBlock(gFormat.format(40), generalSettings.safetyVal + "T0");
              }
            } else {
              writeBlock(gMotionModal.format(0), gMotionModal.format(40), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + "T0");
            }
          } else {
            if (generalSettings.toolpost == "subCrossWorking") {
              writeBlock(gMotionModal.format(0), gMotionModal.format(40), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + "T0");
            } else {
              writeBlock(gMotionModal.format(40), generalSettings.safetyVal + "T0");
            }
          }

        }
      } else {
        if (currentSection.getParameter("operation:isRotaryStrategy")) {
          if (generalSettings.toolpost == "gangEndWorking") {
            writeBlock(gMotionModal.format(0), gMotionModal.format(40), "X#100450+1.0" + "T0");
          } else if (generalSettings.toolpost == "oppositeEndWorking1") {
            if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
              writeBlock(gMotionModal.format(0), gMotionModal.format(40), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + "T0");
            } else {
              if (currentSection.isMultiAxis()) {
                writeBlock(gMotionModal.format(0), gMotionModal.format(40), "Z" + zFormat.format((-1 - tool.diameter / 2) * -1) + "T0");
              } else {

                writeBlock(gMotionModal.format(0), gMotionModal.format(40), generalSettings.safetyVal + "T0");
              }
            }
          } else {

            writeBlock(gMotionModal.format(0), gMotionModal.format(40), generalSettings.safetyVal + "T0");
          }
        } else {
          writeBlock(gMotionModal.format(0), gMotionModal.format(40), generalSettings.safetyVal + "T0");
        }
      }
      if (properties.useG50OnGang && generalSettings.g50Offset) {
        writeBlock(gFormat.format(50), wOutput.format(generalSettings.g50Offset * -1));
      }
    }
    machineState.usePolarMode = false;
    forceXZCMode = false;
    forcePolarMode = false;
    partCutoff = false;
    onCommand(COMMAND_STOP_SPINDLE);
    //need an M147 after using the turret on an M machine
    if (description.includes("M5") && (tool.number >= 20 && tool.number <= 29)) {
      writeBlock(mFormat.format(147));
    }
    closedSection = true;
    forceAny();
    shouldRedirect = false;
    tooloffsetOutput = false;
    if (properties.subroutineAll) {
      writeBlock(mFormat.format(99));
    }
  } else {
    if (gotBAxis && (generalSettings.toolpost == "gangBaxisDriven" || generalSettings.toolpost == "gangBaxisManual")) {
      //not this one!
      cancelWorkPlane();
      GroupedbAxis = true;
    }
  }
  if (properties.optionalStop) {
    onCommand(COMMAND_OPTIONAL_STOP);
    gMotionModal.reset();
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
    var modelImage = outputDocuments[i].image;
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
