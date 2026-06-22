
description = "Alkart Wizard L320-XIIB5";
vendor = "Citizen";
vendorUrl = "https://www.citizen.com";
legal = "Copyright (C) 2012-2018 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 40783;

longDescription = "Interface L320-XIIB5 with Akart CNC Wizard";
capabilities = CAPABILITY_MILLING | CAPABILITY_TURNING | CAPABILITY_SETUP_SHEET;
mimetype = "text/html";
keywords = "MODEL_IMAGE PREVIEW_IMAGE PREVIEW_IMAGE_ALWAYS";
setCodePage("utf-8");
include("Common800.cps");

generalSettings = {};
//-------------------------------------------------------------------------------------------------------------------------------
backSpindleCross = {
  toolpost: "backSpindleCross",
  encoder: 5,
  spindleOnCW: 180,
  spindleOnCCW: 181,
  spindleOff: 183,
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  xScale: 1,
  yScale: 1,
  zScale: -1,
  zDir: 1
};

backSpindleFace = {
  toolpost: "backSpindleFace",
  encoder: 5,
  spindleOnCW: 180,
  spindleOnCCW: 181,
  spindleOff: 182,
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  xScale: 2,
  yScale: 2,
  zScale: 1,
  zDir: 1
};

gangTurning = {
  toolpost: "gangTurning",
  encoder: 1,
  spindleOnCW: 3,
  spindleOnCCW: 4,
  spindleOff: 5,
  safetyVal: "X#100450+" + xFormat.format(toPreciseUnit(1.0, MM)),
  fluctuation: { on: mFormat.format(96), off: mFormat.format(97) },
  xScale: 2,
  yScale: 1,
  zScale: -1,
  zDir: 1
};

gangEndWorking = {
  toolpost: "gangEndWorking",
  encoder: { live: 3, static: 1 },
  spindleOnCW: { live: 80, static: 3 },
  spindleOnCCW: { live: 81, static: 4 },
  spindleOff: { live: 82, static: 5 },
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  fluctuation: { on: mFormat.format(96), off: mFormat.format(97) },
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1,
  prepositionOnToolChange: true,
  bAxis: false
};

gangCrossWorking = {
  toolpost: "gangCrossWorking",
  encoder: 3,
  spindleOnCW: 80,
  spindleOnCCW: 81,
  spindleOff: 82,
  safetyVal: "X#100450+" + xFormat.format(toPreciseUnit(1.0, MM)),
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1,
  compLeft: 41,
  compRight: 42,
  g50Offset: 15,
  bAxis: false
};
gangBaxisDriven = {
  toolpost: "gangBaxisDriven",
  encoder: 3,
  spindleOnCW: 80,
  spindleOnCCW: 81,
  spindleOff: 82,
  safetyVal: "X#100450",
  bAxisOffset: 15,
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1,
  compLeft: 42,
  compRight: 41,
  bAxis: true,
  newGen: false
};

oppositeEndWorking1 = {
  toolpost: "oppositeEndWorking1",
  encoder: { live: 4, static: 1 },
  spindleOnCW: { live: 83, static: 3 },
  spindleOnCCW: { live: 84, static: 4 },
  spindleOff: { live: 85, static: 5 },
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1,
  bAxis: false
};

oppositeEndWorking2 = {
  toolpost: "oppositeEndWorking2",
  encoder: { live: 4, static: 1 },
  spindleOnCW: { live: 83, static: 3 },
  spindleOnCCW: { live: 84, static: 4 },
  spindleOff: { live: 85, static: 5 },
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  xScale: 2,
  yScale: 1,
  zScale: -1,
  zDir: 1,
  bAxis: false
};

backToolPostStatic = {
  toolpost: "backToolPostStatic",
  encoder: { live: 5, static: 2 },
  spindleOnCW: { live: 180, static: 23 },
  spindleOnCCW: { live: 181, static: 24 },
  spindleOff: { live: 182, static: 25 },
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  fluctuation: { on: mFormat.format(94), off: mFormat.format(95) },
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1
};

subCrossWorking = {
  toolpost: "subCrossWorking",
  encoder: 5,
  spindleOnCW: 180,
  spindleOnCCW: 181,
  spindleOff: 182,
  safetyVal: "X#100450+" + xFormat.format(toPreciseUnit(1.0, MM)),
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1
};

backToolPostTurning = {
  toolpost: "backToolPostTurning",
  encoder: 2,
  spindleOnCW: 23,
  spindleOnCCW: 24,
  spindleOff: 25,
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  fluctuation: { on: mFormat.format(94), off: mFormat.format(95) },
  xScale: 2,
  yScale: -2,
  zScale: -1,
  zDir: 1
};

oppositeFaceDriven = {
  toolpost: "oppositeFaceDriven",
  encoder: 4,
  spindleOnCW: 83,
  spindleOnCCW: 84,
  spindleOff: 85,
  safetyVal: "Z" + zFormat.format(toPreciseUnit(-1.0,MM)),
  xScale: 1,
  yScale: 1,
  zScale: 1,
  zDir: 1
};

function errormessage() {
  if (currentSection.getType() == TYPE_TURNING) {
    error(localize("Current feature (" + getParameter("operation-comment") + ") is TURNING - Incorrect tool number selected ( Tool " + tool.number + " is invalid for the " + generalSettings.toolpost + "  toolpost)"));
  } else {
    error(localize("Current feature (" + getParameter("operation-comment") + ") is MILLING - Incorrect tool number selected ( Tool " + tool.number + " is invalid for the " + generalSettings.toolpost + "  toolpost)"));
  }
}

setMachineStyle = function (tool) {
  if (debugMode) {
    if ((currentSection.getType() == TYPE_MILLING)) {
      writeBlock("MILLING");
    } else {
      writeBlock("TURNING");
    }
  }

  // Alarm if range of tools aren't applicable for main or sub operations.
    if (currentSection.spindle == SPINDLE_PRIMARY && tool.number >= 30){
        error (localize("Tool " + tool.number + " is not available on the Main Spindle!"))
    } else if (currentSection.spindle != SPINDLE_PRIMARY && tool.number <= 30){
        error (localize("Tool " + tool.number + " is not available on the Sub Spindle!"))
    }

  if (tool.number >= 27 && tool.number <= 30 || tool.number >= 15 && tool.number <= 20 || tool.number > 38 || tool.number == 10) {
    error(localize("Tool " + tool.number + " is not available on this machine!  Check " + getParameter("operation-comment")))
  }

  
  //--------------------------
  if (currentSection.spindle == SPINDLE_PRIMARY) {
    if (tool.number >= 1 && tool.number <= 6) {
      if (currentSection.getType() == TYPE_MILLING) {
        errormessage();
      } else {
        generalSettings = gangTurning;
        if (debugMode) {
          writeBlock("Main Spindle Gang Turning");
          writeBlock("Tool is :- " + tool.number);
        }
      }
    } else if (tool.number >= 7 && tool.number <= 8) {
      if ((currentSection.getType() == TYPE_MILLING)) {
        generalSettings = gangCrossWorking;
        if (debugMode) {
          writeBlock("Main Spindle Gang Cross Working");
          writeBlock("Tool is :- " + tool.number);
        }
        //add g50 shift here
      } else {
        errormessage();
      }
    } else if (tool.number == 9) {
      if ((currentSection.getType() == TYPE_MILLING)) {
        if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
          generalSettings = gangEndWorking;
          generalSettings.bAxis = false;
        } else {
          generalSettings = gangCrossWorking;
          //add g50 shift here
        }

        if (debugMode) {
          writeBlock("Main Spindle Gang End Working - MILLING ");
          writeBlock("Tool is :- " + tool.number);
        }
      } else {
        generalSettings = gangEndWorking;
        if (debugMode) {
          writeBlock("Main Spindle Gang End Working - TURNING ");
          writeBlock("Tool is :- " + tool.number);
        }
      }
    } else if (tool.number >= 11 && tool.number <= 14) {
      if ((currentSection.getType() == TYPE_MILLING) && (tool.liveTool == true)) {
        generalSettings = gangBaxisDriven;
        if (debugMode) {
          writeBlock("Main Spindle Gang B Axis Driven");
          writeBlock("Tool is :- " + tool.number);
        }
      } else {
        error(localize("Static Operations are not supported with this tool number"));
      }
    }
    else if (tool.number >= 21 && tool.number <= 26) {
      //generalSettings = oppositeEndWorking2;
      if ((currentSection.getType() == TYPE_MILLING)) {
        if (tool.number >= 24 && tool.number <= 26) {
          errormessage();
        }
        else {
          generalSettings = oppositeEndWorking1;
          if (debugMode) {
            writeBlock("Main Spindle Opposite End Working - MILLING");
            writeBlock("Tool is :- " + tool.number);
          }
        }
      }
      else {
        generalSettings = oppositeEndWorking2;
        if (debugMode) {
          writeBlock("Main Spindle Opposite End Working - TURNING");
          writeBlock("Tool is :- " + tool.number);
        }
      }
    }
    else if (tool.number >= 31 && tool.number <= 38) {
      if ((currentSection.getType() != TYPE_MILLING)) {
        generalSettings = oppositeEndWorking2;

        if (debugMode) {
          writeBlock("Main Spindle Opposite End Working - TURNING");
          writeBlock("Tool is :- " + tool.number);
        }
      } else {
        error(localize("Tool is Invalid for Main Spindle operations - check Tool " + tool.number + " in feature " + + getParameter("operation-comment")));
      }
    }
  }
  else {
    if (tool.number >= 31 && tool.number <= 38) {
      if (currentSection.getType() == TYPE_TURNING || currentSection.getParameter("operation-strategy") == "drill") {
        generalSettings = backToolPostTurning;
        if (debugMode) {
          writeBlock("Sub Spindle Opposite End Working - TURNING");
          writeBlock("Tool is :- " + tool.number);
        }
      } else {
        if ((currentSection.getType() == TYPE_MILLING)) {
          if (tool.number <= 34 && tool.number >= 31) {
            if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_RADIAL) {
              generalSettings = subCrossWorking;
            } else {
              generalSettings = backToolPostStatic;
            }
          }
          else {
            error(localize("Invalid orientation for T" + tool.number + " - check " + getParameter("operation-comment")))
          }
          if (debugMode) {
            writeBlock("Sub Spindle Opposite End Working - MILLING");
            writeBlock("Tool is :- " + tool.number);
          }

        }
      }
    }
  }
};

//override this in each post with what's needed
setupMachine = function () {
  // override built-in properties
  gotYAxis = (tool.number >= 21 && tool.number <= 26 || tool.number >= 7 && tool.number <= 14 || tool.number >= 31 && tool.number <= 39 && !currentSection.getType() == TYPE_TURNING);
  yAxisMinimum = toPreciseUnit(-50, MM); // specifies the minimum range for the Y-axis
  yAxisMaximum = toPreciseUnit(50, MM); // specifies the maximum range for the Y-axis
  xAxisMinimum = toPreciseUnit(-30, MM); // specifies the maximum range for the X-axis (RADIUS MODE VALUE)
  gotBAxis = true; // tag B-axis always requires customization to match the machine specific functions for doing rotations
  bAxisIsManual = false; // B-axis is manually set and not programmable
  gotMultiTurret = false; // specifies if the machine has several turrets
  gotPolarInterpolation = true; // specifies if the machine has XY polar interpolation capabilities
  gotSecondarySpindle = true;
  gotDoorControl = false;
  toolFormat = createFormat({ decimals: 0, width: 4, zeropad: true });
  properties.useG400 = false;
  // create machine configs
  var bAxisMain = createAxis({ coordinate: 1, table: false, axis: [0, -1, 0], range: [properties.increaseBAxisStroke? 110.0: 90.5, -45], preference: 1 });
  var cAxisMain = createAxis({ coordinate: 2, table: true, axis: [0, 0, -1], cyclic: true, range: [0, 99999], preference: 0, tcp:true }); // C axis is modal between primary and secondary spindle
  var bAxisSub = createAxis({ coordinate: 1, table: false, axis: [0, -1, 0], range: [-45, properties.increaseBAxisStroke? 110.0: 90.5], preference: 0 });
  var cAxisSub = createAxis({ coordinate: 2, table: true, axis: [0, 0, 1], cyclic: false, range: [0, 99999], preference: 0 }); // C axis is modal between primary and secondary spindle
  machineConfigurationMainSpindle = gotBAxis ? new MachineConfiguration(bAxisMain, cAxisMain) : new MachineConfiguration(cAxisMain);
  machineConfigurationSubSpindle = gotBAxis ? new MachineConfiguration(bAxisSub, cAxisSub) : new MachineConfiguration(cAxisSub);
 
  if (!gotYAxis) {
    yOutput.disable();
  }
  aOutput.disable();
  if (!gotBAxis) {
    bOutput.disable();
  } else {
    bOutput.enable();
  }
  // activate machine config
  machineConfiguration = (currentSection.spindle == SPINDLE_PRIMARY) ? machineConfigurationMainSpindle : machineConfigurationSubSpindle;
  if (!gotBAxis || bAxisIsManual) {
    if ((getMachiningDirection(currentSection) == MACHINING_DIRECTION_AXIAL) && !currentSection.isMultiAxis()) {
      machineConfiguration.setSpindleAxis(new Vector(0, 0, 1));
    } else {
      machineConfiguration.setSpindleAxis(new Vector(1, 0, 0));
    }
  } else {
    if (getMachiningDirection(currentSection) == MACHINING_DIRECTION_AXIAL && !currentSection.isMultiAxis()) {
      machineConfiguration.setSpindleAxis(new Vector(0, 0, 1)); // set the spindle axis depending on B0 orientation
    } else {
      if (tool.number <= 14 && tool.number >= 11) {
        machineConfiguration.setSpindleAxis(new Vector(0, 0, 1)); // set the spindle axis depending on B0 orientation
      } else {
        machineConfiguration.setSpindleAxis(new Vector(1, 0, 0)); // set the spindle axis depending on B0 orientation
      }
    }
  }
};
//-----------------------------------------------------------------------------------------------------------------------------------
