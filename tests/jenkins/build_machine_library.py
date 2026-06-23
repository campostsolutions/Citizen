#!/usr/bin/python3
# -*- coding: utf-8 -*-

import argparse
import os
import json
import sys
import shutil
import xml.etree.ElementTree as ET
import zipfile
from stat import *
import base64
import hashlib
import requests
import urllib
from pathlib import Path
import git_utils

#=============================================================================
printDebugEnabled = False
printWarningEnabled = True
printProgressEnabled = True

firstPostRevision = 45805

# Parse command line
parser = argparse.ArgumentParser(description='Build machine library')
parser.add_argument('--source', type=str,
                   help='Source folder, where to get machines')
parser.add_argument('--destination', type=str,
                   help='Destination folder, where to put result')
parser.add_argument('--buildArtifact', action='store_true',
                   help='Identify if the script is being run as part of the build artifact process')

args = parser.parse_args()

scriptFolder = os.path.dirname(os.path.realpath(sys.argv[0]))
rootFolder = scriptFolder

if args.source:
  machinesFolder = args.source
else:
  machinesFolder = os.path.normpath(os.path.join(rootFolder, "../machines"))

if args.destination:
  distFolder = args.destination
else:
  distFolder = os.path.join(rootFolder, "dist2")

zipConnectors = []
machineConnectorsFolder = os.path.normpath(os.path.join(rootFolder, "../machine_connectors"))

#=============================================================================
def printError(message):
  print("Error: " + message)

#=============================================================================
def printWarning(message):
  if (printWarningEnabled):
    print("Warning: " + message)

#=============================================================================
def printDebug(message):
  if (printDebugEnabled):
    print(message)

#=============================================================================
def printProgress(message):
  if (printProgressEnabled):
    print(message)

#=============================================================================
def intro():
  print("Autodesk CAM Machines Library")
  print("")

def extractPostName(post: str):
  return post.split("/")[-1]

def fixPostName(post: str):
  return "system://" + extractPostName(post)

#=============================================================================
def isCopiedToArtifact(filename) -> bool:
  if filename.endswith(".mch"):
    return True
  if filename.endswith(".machine"):
    return True
  # Do not package f3d files to artifact
  if filename.endswith(".f3d"):
    return not args.buildArtifact
  return False
#=============================================================================
# Collect list of machine files recursively
#=============================================================================
def collectMachines(folder, machines):
  printDebug("Folder: " + folder)
  for filename in sorted(os.listdir(folder)):
    fullPath = os.path.join(folder, filename)
    if os.path.isdir(fullPath):
      collectMachines(fullPath, machines)
    if isCopiedToArtifact(filename):
      if filename.__contains__("_"):
        # '_' are used as a substitution character for spaces on cam.autodesk.com - use a space instead
        printError("machine filename cannot contain '_' (skipping " + filename + ")")
        continue

      name = os.path.splitext(filename)[0]
      if name.startswith("."):
        printError("No filename (skipping " + filename + ")")
        continue
      
      # Don't add duplicates and prevent adding machines if we've already got the f3d
      if fullPath not in machines and (os.path.splitext(fullPath)[0] + ".f3d") not in machines:
        printDebug("Machine: " + fullPath)
        machines.append(fullPath)

#=============================================================================
# Collect list of zip machine connectors 
#=============================================================================      
def collectZipMachineConnectors(folder, machineConnectors):
  printDebug("Folder: " + folder)
  zipFiles = list(filter(lambda str: (str.endswith(".zip")), os.listdir(folder)))
  zipFilesNames = list(map(lambda str: (str.split('.')[0]) , zipFiles))
  machineConnectors.extend(zipFilesNames)

#=============================================================================
# Base machine class
#=============================================================================
class Machine:
  def __init__(self, path):
    self.__path = path

  #===========================================================================
  def getUserFacingInfo(self):
    machineDesc = {
      "schemaVersion": 1
    }

    # Hidden machine
    if self.__path.lower().find('hidden') >= 0:
      machineDesc['hidden'] = True

    return machineDesc

  #===========================================================================
  def getPath(self):
    return self.__path

  #===========================================================================
  def getImage(self):
    pass

  #===========================================================================
  def setImage(self, source):
    pass
  
  #===========================================================================
  def setModelPath(self, path):
    pass

  #===========================================================================
  def fixPostsPath(self):
    pass

  #===========================================================================
  def saveAs(self, basePath):
    pass

  #===========================================================================
  def getPreviousVersions(self):
    return []
# End of class Machine
#=============================================================================

#=============================================================================
# Machine's namespace
ns = '{http://www.hsmworks.com/xml/2009/machine}'
ET.register_namespace("", "http://www.hsmworks.com/xml/2009/machine")

#=============================================================================
# XML helpers
#=============================================================================
def convertType(attrib):
  if attrib == "yes":
    return True
  if attrib == "no":
    return False
  if attrib.endswith("mm"):
    attrib = attrib.strip("mm")
  try:
    return int(attrib)
  except:
    try:
      return float(attrib)
    except:
      return attrib

#=============================================================================
def getAttributes(source, filter):
  dest = {}
  for attrib in source.attrib:
    if len(filter) == 0 or attrib in filter:
      dest[attrib] = convertType(source.attrib[attrib])
  return dest

#=============================================================================
def loadTagWithAttributes(root, name, desc, filter=[]):
  source = root.findall(ns + name)
  if (source != None) and (len(source) > 0):
    if (len(source) == 1):
      desc[name] = getAttributes(source.pop(), filter)
    else:
      dest = []
      for tag in source:
        dest.append(getAttributes(tag, filter))
      desc[name] = dest

#=============================================================================
# Legacy machine class
#=============================================================================
class MachineV1(Machine):
  def __init__(self, path, root):
    super().__init__(path)
    self.__root = root

  #===========================================================================
  # Load user-facing info
  def getUserFacingInfo(self):
    if self.__root == None:
      return None

    machineDesc = super().getUserFacingInfo()

    # UUID
    if 'uuid' in self.__root.attrib:
      machineDesc['uuid'] = self.__root.attrib['uuid']

    # Version
    if 'version' in self.__root.attrib:
      machineDesc['version'] = self.__root.attrib['version']
    else:
      machineDesc['version'] = "1.0"

    # Load simple text fields
    for propName in ["vendor", "model", "description"]:
      prop = self.__root.find(ns + propName)
      if prop != None and prop.text != None:
        machineDesc[propName] = prop.text

    # Machining processes
    machiningList = []
    machining = self.__root.find(ns + "machining")
    if machining != None:
      for attrib in machining.attrib:
        if machining.attrib[attrib] == "yes":
          machiningList.append(attrib.upper())
    else:
      machiningList.append("MILLING")
    machineDesc["machining"] = ' '.join(machiningList)

    # Axis
    loadTagWithAttributes(self.__root, 'axis', machineDesc, ["id", "link"])
    
    # Additive plate dimensions
    if "ADDITIVE" in machiningList:
      loadTagWithAttributes(self.__root, 'dimensions', machineDesc, ["depth", "height", "width"])

    # Coolant
    coolant = self.__root.find(ns + "coolant")
    if coolant != None and 'options' in coolant.attrib:
      machineDesc["coolant"] = coolant.attrib['options']

    # Post
    postTag = self.__root.find(ns + "post")
    if postTag != None:
      postFileTag = postTag.find(ns + "postProcessor")
      if postFileTag != None and postFileTag.text != None:
        post = extractPostName(postFileTag.text)
        machineDesc["posts"] = [{"id": post, "file": post}]

    # Machine Connector
    machineConnector = self.__root.find(ns + "machine_connector")
    if machineConnector != None:
      if machineConnector.attrib['capability'].lower() == "yes":
        machineConnectorApp = machineConnector.find(ns + "application")
        if machineConnectorApp != None:
          machineDesc["machineConnectorName"] = machineConnectorApp.attrib['machineConnectorPath'].split("//")[1]

    # Max number of tools
    tooling = self.__root.find(ns + "tooling")
    if tooling != None and 'numberOfTools' in tooling.attrib:
      machineDesc["maxNumberOfTools"] = int(tooling.attrib["numberOfTools"])
    
    # Tool change time
    tooling = self.__root.find(ns + "machiningTime")
    if tooling != None and 'toolChangeTime' in tooling.attrib:
      machineDesc["toolChangeTime"] = round(float(tooling.attrib["toolChangeTime"].strip('s')))

    # Additive Technology
    additive = self.__root.find(ns + "additive")
    if additive != None and 'technology' in additive.attrib:
      machineDesc["additiveTechnology"] = additive.attrib['technology']

    return machineDesc

  #===========================================================================
  def getImage(self):
    imgTag = self.__root.find(ns + "png128")
    if imgTag != None and imgTag.text != None:
      return imgTag.text
    else:
      return None

  #===========================================================================
  def setImage(self, source):
    if self.__root != None:
      image = self.__root.find(ns + "png128")
      if image !=  None:
        # Replace the image path to the website url
        image.text = source

  #===========================================================================
  def setModelPath(self, path):
    fusionTag = self.__root.find(ns + "fusion")
    if fusionTag:
      modelTag = fusionTag.find(ns + "model")
      if modelTag != None:
        modelTag.text = path

  #===========================================================================
  def fixPostsPath(self):
    postTag = self.__root.find(ns + "post")
    if postTag != None:
      postFileTag = postTag.find(ns + "postProcessor")
      if postFileTag != None and postFileTag.text != None:
        postFileTag.text = fixPostName(postFileTag.text)

  #===========================================================================
  def saveAs(self, basePath):
    fullPath = basePath + ".machine"
    et = ET.ElementTree(element=self.__root)
    et.write(fullPath, encoding='utf-8', xml_declaration=True)
    return fullPath

# End of class MachineV1
#=============================================================================

#===========================================================================
def axisDesc(part):
  axis = {}
  if "name" in part:
    axis["id"] = part["name"]
  return axis

#===========================================================================
def fillAxisList(parts, axes):
  link = "undefined"
  for part in parts:
    partType = part["type"]
    if partType == "head":
      return "head"
    elif partType == "table":
      return "table"
    else:
      if "parts" in part:
        link = fillAxisList(part["parts"], axes)
      if partType in ["rotary", "linear"]:
        axis = axisDesc(part)
        axis["link"] = link
        axes.insert(0, axis)

  return link

#===========================================================================
def fillCoolantsList(parts, coolants):
  for part in parts:
    if "tool_station" in part:
      tool_station = part["tool_station"]
      if "coolants" in tool_station:
        coolantss = tool_station["coolants"]
        if coolantss != None:
          for coolant in coolantss:
            # Don't add duplicate coolants
            if coolant not in coolants:
              coolants.append(coolant)
    if "parts" in part:
      fillCoolantsList(part["parts"], coolants)

#=============================================================================
# New machine class
#=============================================================================
class MachineV2(Machine):
  def __init__(self, path, json):
    super().__init__(path)
    self.__json = json

  #===========================================================================
  # Load user-facing info
  def getUserFacingInfo(self):
    if self.__json == None:
      return None

    machineDesc = super().getUserFacingInfo()

    # Version
    machineDesc['version'] = "1.0"

    # Load simple text fileds
    for propName in ["vendor", "model", "description"]:
      prop = self.__json["general"].get(propName)
      if prop == None:
        machineDesc[propName] = ""
      else:
        machineDesc[propName] = prop

    # Minimum post revision
    machineDesc['minimumRevision'] = self.minimumRevision()

    # Machining processes
    machiningList = []
    if "capabilities" in self.__json["general"]:
      machiningList = self.__json["general"]["capabilities"]
    else:
      machiningList.append("MILLING")
    machineDesc["machining"] = (' '.join(machiningList)).upper()
    
    # Axes
    if "kinematics" in self.__json:
      axes = []
      fillAxisList(self.__json["kinematics"]["default"]["parts"], axes)
      machineDesc["axis"] = axes
      coolants = []
      fillCoolantsList(self.__json["kinematics"]["default"]["parts"], coolants)
      # Don't add coolants if machine doesn't have any
      if len(coolants) != 0:
        machineDesc["coolant"] = (' '.join(coolants)).upper()

    # Posts
    if "post" in self.__json:
      posts = []
      for key, value in self.__json["post"].items():
        if value is not None:
          posts.append({
            "id": key,
            "file": extractPostName(value["path"])})
      if posts:
        machineDesc["posts"] = posts

    # Connector
    pathToConnector = self.__json.get("connector",{}).get("default",{}).get("path")
    if pathToConnector != None:
      machineDesc["machineConnectorName"] = pathToConnector.split("//")[1]

    # Max tool number
    maxToolNumber = self.__json.get("tooling",{}).get("default",{}).get("number_of_tools")
    if(maxToolNumber != None):
      machineDesc["maxNumberOfTools"] = maxToolNumber
    
    # Tool change time
    toolChangeTime = self.__json.get("machining",{}).get("default",{}).get("tool_change_time")
    if(toolChangeTime != None):
      machineDesc["toolChangeTime"] = toolChangeTime

    # Additive machine dimension
    size = self.__json.get("platform",{}).get("default",{}).get("dimensions",{}).get("size")
    if size != None and len(size) == 3:
      # Make it consistent with MachineV1 format
      machineDesc["dimensions"] = {"depth":size[1], "height":size[2], "width":size[0]}
    
    # Additive technology
    technology = self.__json.get("additive",{}).get("default",{}).get("technology")
    if technology != None:
      machineDesc["additiveTechnology"] = technology

    return machineDesc

  def getOrCreateFusionComponent(self):
    if not "fusion" in self.__json:
      self.__json["fusion"] = {"default":{}}
    return self.__json["fusion"]["default"]

  #===========================================================================
  def getImage(self):
    if not "fusion" in self.__json:
      return None
    fusion = self.__json["fusion"]
    if not "default" in fusion:
      return None
    fusionDefault = fusion["default"]
    if not "image" in fusionDefault:
      return None
    return fusionDefault["image"]

  #===========================================================================
  def setImage(self, source):
    self.getOrCreateFusionComponent()["image"] = source

  #===========================================================================
  def setModelPath(self, path):
    self.getOrCreateFusionComponent()["model_urn"] = path

  #===========================================================================
  def fixPostsPath(self):
    if "post" in self.__json:
      for key, value in self.__json["post"].items():
        if self.__json["post"][key] is not None:
          self.__json["post"][key]["path"] = fixPostName(value["path"])

  #===========================================================================
  def saveAs(self, basePath):
    fullPath = basePath + ".mch"
    file = open(fullPath, "w")
    json.dump(self.__json, file, indent=2)
    file.close()
    return fullPath

  def minimumRevision(self):
    if "minimumRevision" in self.__json["general"]:
      return self.__json["general"]["minimumRevision"]
    else:
      return firstPostRevision

  #===========================================================================
  # Returns list of previous machine versions. List contains only machines
  # with breaking changes, when minimum post revision is different from latest
  # one. Also, it contains only latest machine for each post engine revision
  def getPreviousVersions(self):
    result = []
    previousRevision = self.minimumRevision()
    if previousRevision <= firstPostRevision:
      return result

    # Load log for original file use .mch only, as for legacy products f3d
    # cannot be used anyway
    machineFileName = os.path.splitext(self.getPath())[0] + ".mch"
    commits = git_utils.getGitLog(machineFileName)
    # For all commits
    for commit in commits:
      # Load machine file
      (out, code, err) = git_utils.readFileFromCommit(commit, machineFileName)
      if code == 0:
        try:
          machineJSON = json.loads(out.decode())
          machine = MachineV2(machineFileName, machineJSON)
          # if revision is different to previous push into result
          if machine.minimumRevision() != previousRevision:
            result.append(machine)
          # check revision, if it is minimum one, stop
          if machine.minimumRevision() <= firstPostRevision:
            break

        except UnicodeDecodeError:
          # Some commits had encoding errors
          pass

    return result

# End of class MachineV2
#=============================================================================

#=============================================================================
def loadMachine(machineFileName):
  try:
    # Load embedded from fusion model
    if machineFileName.endswith(".f3d"):
      with zipfile.ZipFile(machineFileName, 'r') as machineZip:
        for name in machineZip.namelist():
          # Legacy machine format
          if (name.endswith("simulation.machine")):
            with machineZip.open(name) as machineFile:
              return MachineV1(machineFileName, ET.fromstring(machineFile.read()))
          # New machine format
          if (name.endswith("simulation.mch")):
            with machineZip.open(name) as machineFile:
              return MachineV2(machineFileName, json.load(machineFile))
        printWarning("Fusion project file does not have a machine " + machineFileName)
    elif machineFileName.endswith(".machine"):
      return MachineV1(machineFileName, ET.parse(machineFileName).getroot())
    elif machineFileName.endswith(".mch"):
      file = open(machineFileName,)
      machineJSON = json.load(file)
      file.close()
      return MachineV2(machineFileName, machineJSON)
    else:
      printWarning("Unsupported file format " + machineFileName)
  except:
    printWarning("Failed to load machine " + machineFileName)

  return None

#=============================================================================
# Returns true, if path exists
#=============================================================================
def isFileExistsSafe(filePath):
  try:
    return os.path.exists(filePath)
  except:
    return False

#=============================================================================
# Load image info and copy the image to destination folder
# Return the image path in the destination folder
#=============================================================================
def processImage(originalImage, machineFileName, distFolder):
  distImagePath = ""
  if machineFileName.endswith(".f3d"):
    with zipfile.ZipFile(machineFileName, 'r') as machineZip:
      for name in machineZip.namelist():
        if (name.startswith("MachineAsset") and name.endswith("small.png")):
          machineBaseName = os.path.splitext(os.path.basename(machineFileName))[0]
          thumbnailFileName = machineBaseName + ".png"
          distImagePath = os.path.join(distFolder, thumbnailFileName)
          with machineZip.open(name) as imageFile:
            with open(distImagePath,'wb') as f:
              shutil.copyfileobj(imageFile, f)

  # Load machine image
  if originalImage != None:
    if originalImage.startswith("http"):
      # Try to download image
      filename = urllib.parse.unquote(originalImage.split("/")[-1])
      distImagePath = os.path.join(distFolder, filename)
      if not os.path.exists(distImagePath):
        response = requests.get(originalImage, stream = True)
        if response.status_code == 200:
          # Image was retrieved successfully
          response.raw.decode_content = True
          with open(distImagePath,'wb') as f:
            shutil.copyfileobj(response.raw, f)
        else:
          # Failed to download the image, return empty path 
          printWarning("Failed to download " + originalImage)
          distImagePath = ""
    else:
      # Relative path
      machineBaseDir = os.path.dirname(machineFileName)
      srcImagePath = os.path.join(machineBaseDir, originalImage)
      if isFileExistsSafe(srcImagePath):
        fileName = os.path.basename(srcImagePath)
        distImagePath = os.path.join(distFolder, fileName)
        if not os.path.exists(distImagePath):
          # Copy it to the destination folder use the old name
          shutil.copyfile(srcImagePath, distImagePath)
      else:
        # Embedded image, return empty path 
        distImagePath = ""
        machineBaseName = os.path.splitext(machineFileName)[0]
        thumbnailFileName = machineBaseName + ".png"
        if not os.path.exists(thumbnailFileName):
          data = base64.b64decode(originalImage)
          f = open(thumbnailFileName, "wb")
          f.write(data)
          f.close()
  return distImagePath

#=============================================================================
def getMachineConnectorFilePath(connectorName):
  sourceConnectorFolder = os.path.normpath(os.path.join(machinesFolder, "../machine_connectors/"))
  return os.path.join(sourceConnectorFolder, connectorName)

#=============================================================================
def processMachineConnectorFile(connectorNameWithExtension, distFolder):
  sourceConnectorFilePath = getMachineConnectorFilePath(connectorNameWithExtension)
  
  if not os.path.isfile(sourceConnectorFilePath):
    printWarning("Fusion project file does not have a connector " + connectorNameWithExtension)
    return

  distConnectorFolder = os.path.join(distFolder, "machine_connectors")
  if not os.path.exists(distConnectorFolder):
    os.makedirs(distConnectorFolder)
  
  distConnectorFilePath = os.path.join(distConnectorFolder, connectorNameWithExtension)
  if not os.path.exists(distConnectorFilePath):
    shutil.copyfile(sourceConnectorFilePath, distConnectorFilePath)

#=============================================================================
def processMachineConnectorFiles(connectorNameWithoutExtension, distFolder):

  if Path(connectorNameWithoutExtension).suffixes:
    printWarning("Machine connector tag should not contain a file extension")
    return
  
  if connectorNameWithoutExtension in zipConnectors:
    zipConnectorName = connectorNameWithoutExtension + ".zip"
    processMachineConnectorFile(zipConnectorName, distFolder)
    # no need to process .exe and .app for zip connectors
    return

  winConnectorName = connectorNameWithoutExtension + ".exe"
  macConnectorName = connectorNameWithoutExtension + ".app"
  processMachineConnectorFile(winConnectorName, distFolder)
  processMachineConnectorFile(macConnectorName, distFolder)

#=============================================================================
def getConnectorFileHashes(connectorNameWithoutExtension):
  winConnectorName = getMachineConnectorFilePath(connectorNameWithoutExtension + ".exe")
  macConnectorName = getMachineConnectorFilePath(connectorNameWithoutExtension + ".app")
  zipConnectorName = getMachineConnectorFilePath(connectorNameWithoutExtension + ".zip")
  fileHashes={}
  if os.path.exists(winConnectorName):
    fileHashes['windows'] = sha256sum(winConnectorName)
  if os.path.exists(macConnectorName):
    fileHashes['mac'] = sha256sum(macConnectorName)
  if os.path.exists(zipConnectorName):
    fileHashes['zip'] = sha256sum(zipConnectorName)
  return fileHashes
#=============================================================================
def sha256sum(fileName):
  h  = hashlib.sha256()
  b  = bytearray(128*1024)
  mv = memoryview(b)
  with open(fileName, 'rb', buffering=0) as f:
    for n in iter(lambda : f.readinto(mv), 0):
      h.update(mv[:n])
  return h.hexdigest()

#=============================================================================
def flattenFileName(fileName):
  sep = " "
  return fileName.replace("\\", sep).replace("/", sep)

#=============================================================================
# Process machine files:
# - Load user-visible data to description
# - Pack machine with all dependencies into single archive
# - Copy machine file, machine image and preview image to destination folder
# - Returns array of descriptions
#=============================================================================
def processMachines(machines):
  descriptions = []
  for machineFileName in machines:
    # Load user visible information
    machine = loadMachine(machineFileName)
    if machine != None:
      # Fusion does not allow to select system post now, so machine files 
      # can have post path from different sources. This call ensures, 
      # that post path always uses proper "system" protocol.
      machine.fixPostsPath()

      machineDesc = machine.getUserFacingInfo()
      descriptions.append(machineDesc)
      # Build flat filename
      flatName = os.path.basename(machineFileName)
      # Base name
      machineBaseName = os.path.splitext(machineFileName)[0]
      # Load and copy machine image to destination folder
      # Won't deal with embedded image for now
      distImagePath = processImage(machine.getImage(), machineFileName, distFolder)
      # Use same name image to generate thumbnail
      thumbnailFileName = machineBaseName + ".png"
      if os.path.exists(thumbnailFileName):
        # Copy and rename the thumbnail image
        filename = os.path.splitext(os.path.basename(flatName))[0] + "_thumbnail.png"
        machineDesc['thumbnail'] = filename
        # TODO: what to do with image?
        shutil.copyfile(thumbnailFileName, os.path.join(distFolder, filename))

      # Update image to use website link
      if os.path.exists(distImagePath):
        imageFileName = os.path.basename(distImagePath)
        machine.setImage("https://cam.autodesk.com/machines/machines/" + urllib.parse.quote(imageFileName))
        machineDesc["image"] = imageFileName
        
      # Copy the connector app
      if "machineConnectorName" in machineDesc:
        processMachineConnectorFiles(machineDesc["machineConnectorName"], distFolder)
        machineDesc["machineConnectorSha256"] = getConnectorFileHashes(machineDesc["machineConnectorName"])

      distFileName = os.path.join(distFolder, flatName)
      # Copy simulation model, if it is a fusion file
      if distFileName.endswith(".f3d"):
        shutil.copyfile(machineFileName, distFileName)
        machineDesc['simulationModel'] = flatName
        machine.setModelPath("https://cam.autodesk.com/machines/machines/" + urllib.parse.quote(flatName))

      # Save machine file because it can be changed
      distMachineFileName = machine.saveAs(os.path.splitext(distFileName)[0])

      # Deal with previous versions
      versions = machine.getPreviousVersions()
      if versions:
        machineDesc['versions'] = {}
        # Push latest version to the list too
        machineDesc['versions'][machine.minimumRevision()] = os.path.basename(distMachineFileName)
        for machineVersion in versions:
          # Fix post path for each version too
          machineVersion.fixPostsPath()
          # Save older version with the 'name_revision' name
          stringRevision = str(machineVersion.minimumRevision())
          versionFileName = os.path.splitext(distFileName)[0] + "_" + stringRevision
          distVersionFileName = machineVersion.saveAs(versionFileName)
          # And add it to the map
          machineDesc['versions'][stringRevision] = os.path.basename(distVersionFileName)

      machineDesc['sha256'] = sha256sum(distMachineFileName)
      machineDesc["filename"] = os.path.basename(distMachineFileName)
  return descriptions

#=============================================================================
# Process machine files for artifact:
# - Copy machine file to destination folder
#=============================================================================
def processMachinesForArtifact(machines):
  for machineFileName in machines:
    # Load user visible information
    machine = loadMachine(machineFileName)
    if machine != None:
      # Fusion does not allow to select system post now, so machine files 
      # can have post path from different sources. This call ensures, 
      # that post path always uses proper "system" protocol.
      machine.fixPostsPath()

      # Handle machine model urn
      modelFileName = os.path.splitext(machineFileName)[0] + ".f3d"
      modelFlatName = os.path.basename(modelFileName)
      if os.path.exists(modelFileName):
        machine.setModelPath("https://cam.autodesk.com/machines/machines/" + urllib.parse.quote(os.path.basename(modelFlatName)))

      # Parse machine image path if available (don't copy it, just use the path)
      originalImage = machine.getImage()
      if originalImage != None:
        distImagePath = ""
        if originalImage.startswith("http"):
          filename = urllib.parse.unquote(originalImage.split("/")[-1])
          distImagePath = os.path.join(distFolder, filename)
        else:
          # Relative path
          machineBaseDir = os.path.dirname(machineFileName)
          srcImagePath = os.path.join(machineBaseDir, originalImage)
          if isFileExistsSafe(srcImagePath):
            fileName = os.path.basename(srcImagePath)
            distImagePath = os.path.join(distFolder, fileName)

        # Update image to use website link
        if distImagePath != "":
          imageFileName = os.path.basename(distImagePath)
          machine.setImage("https://cam.autodesk.com/machines/machines/" + urllib.parse.quote(imageFileName))
      

      # Save machine file because it can be changed
      flatName = os.path.basename(machineFileName)
      distFileName = os.path.join(distFolder, flatName)
      machine.saveAs(os.path.splitext(distFileName)[0])

#=============================================================================
def generateLibraryList(allMachines, destinationFolder):
  publicList = []
  hiddenList = []
  for path in allMachines:
    filename = os.path.basename(path)
    if path.lower().find('hidden') >= 0:
      hiddenList.append(filename)
    else:
      publicList.append(filename)

  destPath = os.path.join(destinationFolder, "machines.txt")
  with open(destPath, "w") as f:
    f.write("Public machines: \n")
    for file in publicList:
      f.write(file + "\n")
    f.write("\nHidden machines: \n")
    for file in hiddenList:
      f.write(file + "\n")

#=============================================================================
# Builds the machines library.
#=============================================================================
def buildLibrary():
  printProgress("Building...")
  if not os.path.exists(distFolder):
    os.makedirs(distFolder)

  printProgress("Collecting machines...")
  machines = []
  collectMachines(machinesFolder, machines)

  collectZipMachineConnectors(machineConnectorsFolder, zipConnectors)

  printProgress("Processing machines...")
  if args.buildArtifact:
    generateLibraryList(machines, distFolder)  
    processMachinesForArtifact(machines)
  else:
    descriptions = processMachines(machines)
    descJSON = json.dumps(descriptions, indent=2)
    printDebug(descJSON)
    dbPath = os.path.join(distFolder, "machines.json")
    f = open(dbPath, "w")
    f.write(descJSON)
    f.close()

  printProgress("Updated {0} machines.".format(len(machines)))

intro()
buildLibrary()

