#!/usr/bin/python3
# -*- coding: utf-8 -*-

import argparse
import os
import json
import sys
import shutil
import xml.etree.ElementTree as ET
from stat import *
import base64
import hashlib
import requests
import urllib
from pathlib import Path

#=============================================================================
printDebugEnabled = False
printWarningEnabled = True
printProgressEnabled = True

# Parse command line
parser = argparse.ArgumentParser(description='Build printsettings library')
parser.add_argument('--source', type=str,
                   help='Source folder, where to get printsettings')
parser.add_argument('--destination', type=str,
                   help='Destination folder, where to put result')

args = parser.parse_args()

scriptFolder = os.path.dirname(os.path.realpath(sys.argv[0]))
rootFolder = scriptFolder

if args.source:
  printsettingsFolder = args.source
else:
  printsettingsFolder = os.path.normpath(os.path.join(rootFolder, "../printsettings"))

if args.destination:
  distFolder = args.destination
else:
  distFolder = os.path.join(rootFolder, "dist2")

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
  print("Autodesk CAM Printsettings Library")
  print("")

#=============================================================================
# Collect list of printsetting files recursively
#=============================================================================
def collectPrintsettings(folder, printsettings):
  printDebug("Folder: " + folder)
  for filename in sorted(os.listdir(folder)):
    fullPath = os.path.join(folder, filename)
    if os.path.isdir(fullPath):
      collectPrintsettings(fullPath, printsettings)
    if filename.endswith(".printsetting") or filename.endswith(".printSetting"):
      name = os.path.splitext(filename)[0]
      if not name.startswith("."):
        # Don't add duplicates and prevent adding printsettings if we've already got the printsetting
        if fullPath not in printsettings and (os.path.splitext(fullPath)[0] + ".printsetting") and (os.path.splitext(fullPath)[0] + ".printSetting")not in printsettings:
          printDebug("Printsetting: " + fullPath)
          printsettings.append(fullPath)




#=============================================================================
# printsetting's namespace
ns = '{http://www.autodesk.com/xml/2019/printsetting}'
ET.register_namespace("", "http://www.autodesk.com/xml/2019/printsetting")

#=============================================================================
# XML helpers
#=============================================================================
def convertType(attrib):
  if attrib == "yes":
    return True
  if attrib == "no":
    return False
  try:
    return int(attrib)
  except:
    try:
      return float(attrib)
    except:
      return attrib

#=============================================================================
def getAttributes(source):
  dest = {}
  for attrib in source.attrib:
    dest[attrib] = convertType(source.attrib[attrib])
  return dest

#=============================================================================
def loadTagWithAttributes(root, name, desc):
  source = root.findall(ns + name)
  if (source != None) and (len(source) > 0):
    if (len(source) == 1):
      desc[name] = getAttributes(source.pop())
    else:
      dest = []
      for tag in source:
        dest.append(getAttributes(tag))
      desc[name] = dest

#=============================================================================
# Legacy printsetting class
#=============================================================================
class Printsetting:
  def __init__(self, path, root):
    self.__path = path
    self.__root = root

  #===========================================================================
  # Load user-facing info
  def getUserFacingInfo(self):
    if self.__root == None:
      return None

    printsettingDesc = {
      "schemaVersion": 1
    }

    # Hidden printsetting
    if self.__path.lower().find('hidden') >= 0:
      printsettingDesc['hidden'] = True


    # Version
    if 'version' in self.__root.attrib:
      printsettingDesc['version'] = self.__root.attrib['version']
    else:
      printsettingDesc['version'] = "1.0"

    # Load simple text fields
    for propName in ["name", "description", "layer_thickness", "vendor", "machine_model", "technology"]:
      prop = self.__root.find(ns + propName)
      if prop != None and prop.text != None:
        printsettingDesc[propName] = prop.text.strip()

    # Technology
    feature = self.__root.find(ns + "solution_feature_list")
    if feature != None and feature.text != None:
      featureType = feature.text.strip()
      if featureType == "0" or featureType.startswith("0"):
          printsettingDesc["technology"]="SLM"
      elif featureType == "1":
          printsettingDesc["technology"]="FFF"
      elif featureType == "7":
          printsettingDesc["technology"]="MJF"
      elif featureType == "8":
          printsettingDesc["technology"]="SLA"
      elif featureType == "9":
          printsettingDesc["technology"]="SLS"
      elif featureType == "10":
          printsettingDesc["technology"]="SLA_EBPA"
      elif featureType == "11":
          printsettingDesc["technology"]="SLS_EBPA"
      else:
          printDebug("Printsetting technology not found " + featureType + ".  path: " + self.__path)



    return printsettingDesc


# End of class Printsetting
#=============================================================================



#=============================================================================
def loadPrintsetting(printsettingFileName):
  try:
    if printsettingFileName.endswith(".printsetting") or printsettingFileName.endswith(".printSetting"):
      return Printsetting(printsettingFileName, ET.parse(printsettingFileName).getroot())
    else:
      printWarning("Unsupported file format " + printsettingFileName)
  except:
    printWarning("Failed to load printsetting " + printsettingFileName)

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
# Process printsetting files:
# - Load user-visible data to description
# - Pack printsetting with all dependencies into single archive
# - Copy printsetting file, printsetting image and preview image to destination folder
# - Returns array of descriptions
#=============================================================================
def processPrintsettings(printsettings):
  descriptions = []
  for printsettingFileName in printsettings:
    # Load user visible information
    printsetting = loadPrintsetting(printsettingFileName)
    if printsetting != None:
      printsettingDesc = printsetting.getUserFacingInfo()
      descriptions.append(printsettingDesc)
      # Build flat filename
      flatName = os.path.basename(printsettingFileName) #flattenFileName(os.path.relpath(printsettingFileName, printsettingsFolder))
      distFileName = os.path.join(distFolder, flatName)
      # Copy printsetting to new destination
      shutil.copyfile(printsettingFileName, distFileName)


      printsettingDesc['sha256'] = sha256sum(distFileName)
      printsettingDesc["filename"] = os.path.basename(distFileName)

  return descriptions

#=============================================================================
# Builds the printsettings library.
#=============================================================================
def buildLibrary():
  printProgress("Building...")
  if not os.path.exists(distFolder):
    os.makedirs(distFolder)

  printProgress("Collecting printsettings...")
  printsettings = []
  collectPrintsettings(printsettingsFolder, printsettings)

  printProgress("Processing printsettings...")
  descriptions = processPrintsettings(printsettings)

  descJSON = json.dumps(descriptions, indent=2)
  printDebug(descJSON)
  dbPath = os.path.join(distFolder, "printsettings.json")
  f = open(dbPath, "w")
  f.write(descJSON)
  f.close()

  printProgress("Updated {0} printsettings.".format(len(printsettings)))

intro()
buildLibrary()
