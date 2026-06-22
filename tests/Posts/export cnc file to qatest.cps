/**
  Copyright (C) 2018 by Autodesk, Inc.
  All rights reserved.

  FORKID {D38E0AF6-F1A7-4C6D-A0FA-C99BB29E65AE}
*/

description = "Export CNC file to Quality Assurance Tests";
vendor = "Autodesk";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2018 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 41666;

longDescription = "The post installs the CNC file for use with the Quality Assurance Tests.  Be sure to select the correct capabilities for this operation.";

capabilities = CAPABILITY_INTERMEDIATE;

var cncFile;
var qaMainFolder;

// user-defined properties
properties = {
  machineType: "milling" // machine capabiilities of operation
};

// user-defined property definitions
propertyDefinitions = {
  machineType: {
    title      : "Machine Configuration",
    description: "Select the machine configuration for this operation.",
    type       : "enum",
    values     : [
      {title:"Milling", id:"milling"},
      {title:"Turning", id:"turning"},
      {title:"WaterJet/Plasma/Laser", id:"jet"},
      {title:"Mill/Turn", id:"millturn"},
      {title:"Mill/Jet", id:"milljet"},
      {title:"Generic", id:"generic"},
      {title:"Additive", id:"additive"},
    ]
  }
};

function getMachineTypeProperty() {
  var ncFile = FileSystem.getFilename(getOutputPath()).split(".");
  writeln("file = " + ncFile);
  switch (ncFile[0]) {
  case "#milling#":
    properties.machineType = "milling";
    break;
  case "#turning#":
    properties.machineType = "turning";
    break;
  case "#jet#":
    properties.machineType = "jet";
    break;
  case "#millturn#":
    properties.machineType = "millturn";
    break;
  case "#milljet#":
    properties.machineType = "milljet";
    break;
  case "#generic#":
    properties.machineType = "generic";
    break;
  case "#additive#":
    properties.machineType = "additive";
    break;
  }
}

function onOpen() {
  // see if filename overrides machineType (from Fusion Create Production CNC Files add-in)

  getMachineTypeProperty();

  qaMainFolder = FileSystem.getFolderPath(getConfigurationFolder());
  var section = getSection(0);
  if (section.hasParameter("autodeskcam:path") || section.hasParameter("hsmworks:path")) {
    var operation = section.hasParameter("autodeskcam:path") ? section.getParameter("autodeskcam:path") : section.getParameter("hsmworks:path");
    var sText2 = new Array();
    sText2 = operation.split("\\");
    if (sText2.length < 3) {
      error(localize("Could not determine folder name."));
      return;
    }
    cncFile = sText2[2];
  } else if (hasGlobalParameter("job-description")) { // additive does not use folders, so use Setup name
    var operation = getGlobalParameter("job-description");
    var sText2 = new Array();
    sText2 = operation.split(":");
    cncFile = sText2[0];
  } else {
    error(localize("Could not determine folder name."));
    return;
  }
}

function onSection() {
  skipRemainingSection();
}

function onClose() {
  var cncPath = getIntermediatePath();
  if (FileSystem.isFile(cncPath)) {
    var userProfile = getEnvironmentVariable("USERPROFILE");
    var customFolder = FileSystem.getCombinedPath(userProfile, qaMainFolder + "\\cnc"); // TAG
    customFolder = FileSystem.getCombinedPath(customFolder, properties.machineType);
    if (!FileSystem.isFolder(customFolder)) {
      // FileSystem.makeFolder(customFolder);
      error(localize("Post Processor QA Test folder not found: ") + customFolder);
    }
    var fileName = FileSystem.replaceExtension(cncFile, "cnc");
    FileSystem.copyFile(cncPath, FileSystem.getCombinedPath(customFolder, fileName));
  }
  writeln("Success, your CNC file " + "\"" + fileName + "\"" + " is now located in " + "\"" + customFolder + "\"" + " and you can use it in the Quality Assurance Tests.");
}

//Dummy function for additive toolpath
function onLinearExtrude() {
}

function onCircularExtrude() {
}
