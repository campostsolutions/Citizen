#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# This script build the machine-connector-addin library intended for publication on our website
#
# Copyright (C) 2021 by Autodesk, Inc.
# All rights reserved.

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

# Parse command line
parser = argparse.ArgumentParser(description='Build connector addin library')
parser.add_argument('--source', type=str,
                   help='Source folder, where to get machine-connector addins')
parser.add_argument('--destination', type=str,
                   help='Destination folder, where to put result')

args = parser.parse_args()

scriptFolder = os.path.dirname(os.path.realpath(sys.argv[0]))
rootFolder = scriptFolder

if args.source:
  machineConnectorAddinFolder = args.source
else:
  machineConnectorAddinFolder = os.path.normpath(os.path.join(rootFolder, "../machine_addins"))

if args.destination:
  distFolder = args.destination
else:
  distFolder = os.path.join(rootFolder, "dist3")

#=============================================================================
printDebugEnabled = False
printWarningEnabled = True
printProgressEnabled = True

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
  print("Autodesk CAM Machine-Connector-Addin Library")
  print("")
  
#=============================================================================
# Get the list of machine connector addin files (full path)
#=============================================================================
def getMachineConnectorAddinFilePaths(folder):
  addinFilePaths = []
  printDebug("Looking in folder: " + folder)
  for addinFileName in os.listdir(folder):
    fullPath = os.path.join(folder, addinFileName)
    if addinFileName.endswith(".zip") and fullPath not in addinFilePaths:
      printDebug("Machine connector addin: " + fullPath)
      addinFilePaths.append(fullPath)
  return addinFilePaths

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
# Get the list of machine connector addin files (full path)
#=============================================================================
def getMachineConnectorAddinDescriptions(addinFilePaths):
  descriptions = []
  for addin in addinFilePaths:
    addinFileName = os.path.split(addin)[1]
    addinFileNameWithoutExtension = os.path.splitext(addinFileName)[0]
    extension = os.path.splitext(addinFileName)[1]
    machineDesc = {
      "name": addinFileNameWithoutExtension,
      "filename": addinFileName,
      "sha256": sha256sum(addin)
    }
    descriptions.append(machineDesc)
  return descriptions

#=============================================================================
# Write the descriptions to a json file for distribution
#=============================================================================
def writeDescriptionsToJsonFile(descriptions):
  descJSON = json.dumps(descriptions, indent=2)
  printDebug(descJSON)
  dbPath = os.path.join(distFolder, "machine-connector-addins.json")
  f = open(dbPath, "w")
  f.write(descJSON)
  f.close()

#=============================================================================
# Copy addins to the distribution folder
#=============================================================================
def createDistribution(addinFilePaths, distFolder):
  for addin in addinFilePaths:
    copyAddinToDistribution(addin, distFolder)

#=============================================================================
# Copy an addin to the distribution folder
#=============================================================================    
def copyAddinToDistribution(addinFilePath, distFolder):
  sourceConnectorFolder = os.path.normpath(machineConnectorAddinFolder)
  sourceConnectorFilePath = os.path.join(sourceConnectorFolder, addinFilePath)
  if not os.path.isfile(sourceConnectorFilePath):
    printWarning("Fusion project file does not have a connector addin" + connectorName)
    return
  
  distConnectorFolder = os.path.join(distFolder, "machine_addins/")
  
  if not os.path.exists(distConnectorFolder):
    os.makedirs(distConnectorFolder)
  
  addinFileName = os.path.split(addinFilePath)[1]
  distConnectorFilePath = os.path.join(distConnectorFolder, addinFileName)

  if not os.path.exists(distConnectorFilePath):
    shutil.copyfile(sourceConnectorFilePath, distConnectorFilePath)  
  
#=============================================================================
# Builds the machine connector addin library.
#=============================================================================
def buildLibrary():
  if not os.path.exists(machineConnectorAddinFolder):
    printWarning("Source folder not found. No work to do.")
    return

  printProgress("Building...")
  if not os.path.exists(distFolder):
    os.makedirs(distFolder)

  printProgress("Find machine-connector addin addinFileNames...")
  addinFilePaths = getMachineConnectorAddinFilePaths(machineConnectorAddinFolder)

  printProgress("Get machine-connector addin descriptions...")
  descriptions = getMachineConnectorAddinDescriptions(addinFilePaths)

  printProgress("Write descriptions to json...")
  writeDescriptionsToJsonFile(descriptions)
  
  printProgress("Copying files to distribution")
  createDistribution(addinFilePaths, distFolder)

  printProgress("Updated {0} machine connector addinFilePaths.".format(len(addinFilePaths)))

intro()
buildLibrary()
