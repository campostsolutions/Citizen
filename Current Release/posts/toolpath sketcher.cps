/**
  Copyright (C) 2012-2016 by Autodesk, Inc.
  All rights reserved.

  $Revision: 41369 65a1f6cb57e3c7389dc895ea10958fc2f7947b0d $
  $Date: 2017-03-20 14:12:44 $

  FORKID {065403A3-A589-43ef-B345-90B5274EE274}
*/

description = "Toolpath drawing";
certificationLevel = 2;
minimumRevision = 24000;
extension = "";

programNameIsInteger = false;
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_TURNING;
tolerance = spatial(0.01, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(90);
allowHelicalMoves = false;
allowedCircularPlanes = 0; // allow any circular motion

function writeBlock() {
  if (properties.showSequenceNumbers) {
    writeWords2(nFormat.format(sequenceNumber % 10000), arguments);
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    writeWords(arguments);
  }
}

var canvas;
var boundingArea;
var scale = 1;
let isTurningOp = false;
let cx = 0;
let cy = 0;
let minx = 0;
let miny = 0;
let minz = 0;
let isRapid = false;
let paddingx = 0;
let paddingy = 0;
let ls = 0;
const permittedCommentChars = " abcdefghijklmnopqrstuvwxyz0123456789.,=_-";

function onSection() {
  canvas = new Canvas(510, 510);
  canvas.clear(16777215);
  boundingArea = currentSection.getBoundingBox();

  const xSize = Math.abs(boundingArea.upper.x - boundingArea.lower.x);
  const ySize = Math.abs(boundingArea.upper.y - boundingArea.lower.y);
  const zSize = Math.abs(boundingArea.upper.z - boundingArea.lower.z);
  let largestSize = xSize;
  ls = 0;
  isTurningOp = currentSection.checkGroup(STRATEGY_TURNING) || currentSection.checkGroup(STRATEGY_DRILLING);
  if (isTurningOp) {
    if (zSize > xSize) {
      largestSize = zSize;
      ls = 2;
    }
  } else {
    if (ySize > xSize) {
      largestSize = ySize;
      ls = 1;
    }
  }

  switch (ls) {
  case 0:
    paddingy = Math.floor((500 - (isTurningOp ? zSize : ySize)) / 2) + 5;
    break;
  case 1:
  case 2:
    paddingx = Math.floor((500 - xSize) / 2) + 5;
    break;
  }

  minx = boundingArea.lower.x;
  miny = boundingArea.lower.y;
  minz = boundingArea.lower.z;

  scale = 500 / largestSize;

  const initialPosition = currentSection.getInitialPosition();
  isRapid = true;
  cx = initialPosition.x;
  cy = isTurningOp ? initialPosition.z : initialPosition.y;
}

function lineLooper(x, y) {
  const fx = (x - cx) * (x - cx);
  const fy = (y - cy) * (y - cy);
  const distance = Math.floor(Math.sqrt(fx + fy));
  const cp = new Vector(x, y, 0);
  if (distance >= 1) {
    for (let i = 0; i < distance; ++i) {
      const shift = new Vector(cx - x, cy - y, 0).getNormalized();
      shift.multiply(i);
      const p = Vector.sum(cp, shift);
      if (p.x >= 500) {
        p.x = 499;
      }
      if (p.y >= 500) {
        p.y = 499;
      }
      if (p.x < 0) {
        p.x = 0;
      }
      if (p.y < 0) {
        p.y = 0;
      }
      canvas.setPixel(Math.floor(p.x), Math.floor(p.y), 4278190335);
    }
  }
}

function onLinear(_x, _y, _z, feed) {
  if (!isRapid) {
    lineLooper((_x - minx) * scale + paddingx, (isTurningOp ? _z - minz : _y - miny) * scale + paddingy);
  } else {
    isRapid = false;
  }
  cx = Math.floor((_x - minx) * scale + paddingx);
  cy = Math.floor(((isTurningOp ? _z : _y) - (isTurningOp ? minz : miny)) * scale + paddingy);
}

function onRapid(_x, _y, _z) {
  isRapid = true;
  if (currentSection.checkGroup(STRATEGY_DRILLING)) {
    isRapid = false;
  }
  cx = Math.floor((_x - minx) * scale + paddingx);
  cy = Math.floor(((isTurningOp ? _z : _y) - (isTurningOp ? minz : miny)) * scale + paddingy);
}

function onLinear5D() {

}
function onRapid5D() {

}
function onSectionEnd() {
  const path = FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), filterText(String(getParameter("operation-comment") + getParameter("autodeskcam:operation-id")), permittedCommentChars) + ".png");
  canvas.saveImage(path, "image/png");
}

function onCyclePoint(x, y, z) {
  if (cycle.depth) {
    lineLooper((x - minx) * scale + paddingx, (z - cycle.depth) * scale + paddingy);
  }
}

function onClose() {
}
