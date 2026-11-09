// zlib.js - the ZOSCII family's general encoder / decoder (gen_encode, gen_decode, gen_frame)
// Copied unchanged from the ZOSCII / UNSIGNAL Attacker page (the same code the creator generates), so the files made here match the creator's.
// (c) 2026 Cyborg Unicorn Pty Ltd
// ES5.
'use strict';
var m_lngRandState = 0;

function gen_brainless(arrBytes_a, intDir_a) { var intI = 0; var intLen = arrBytes_a.length; if (intLen > 0 && intDir_a == 1) { for (intI = intLen - 2; intI >= 0; intI--) { arrBytes_a[intI] = arrBytes_a[intI] ^ arrBytes_a[intI + 1]; } arrBytes_a[intLen - 1] = arrBytes_a[intLen - 1] ^ arrBytes_a[0]; } else if (intLen > 0 && intDir_a == 2) { for (intI = 1; intI < intLen; intI++) { arrBytes_a[intI] = arrBytes_a[intI] ^ arrBytes_a[intI - 1]; } arrBytes_a[0] = arrBytes_a[0] ^ arrBytes_a[intLen - 1]; } }
function gen_buildWindow(arrROM_a, intOffset_a, intSize_a) { var arrWindow = []; var intI = 0; var intROMLen = arrROM_a.length; for (intI = 0; intI < 256; intI++) { arrWindow.push([]); } for (intI = 0; intI < intSize_a; intI++) { if (intOffset_a + intI < intROMLen) { arrWindow[arrROM_a[intOffset_a + intI]].push(intI); } } return arrWindow; }
function gen_crc32Std(arrBytes_a) { var lngCrc = 0xFFFFFFFF; var lngX = 0; var intI = 0; var intJ = 0; var intLen = arrBytes_a.length; for (intI = 0; intI < intLen; intI++) { lngX = (lngCrc ^ arrBytes_a[intI]) & 0xFF; for (intJ = 0; intJ < 8; intJ++) { if ((lngX & 1) != 0) { lngX = ((lngX >>> 1) ^ 0xEDB88320) >>> 0; } else { lngX = lngX >>> 1; } } lngCrc = ((lngCrc >>> 8) ^ lngX) >>> 0; } return (lngCrc ^ 0xFFFFFFFF) >>> 0; }
function gen_romHash(arrBytes_a) { var lngHash = 0; var intI = 0; var intLen = arrBytes_a.length; for (intI = 0; intI < intLen; intI++) { lngHash = ((lngHash * 33) + arrBytes_a[intI]) >>> 0; } return lngHash; }
function gen_effSize(intROMLen_a, intCap_a, blnSliding_a) { var intSize = intCap_a; if (intROMLen_a < intCap_a) { intSize = intROMLen_a; } if (blnSliding_a) { intSize = gen_regime(intROMLen_a, intCap_a).size; } return intSize; }
function gen_hdrValue(arrOut_a, arrHdrWindow_a, intValue_a, intWidth_a, intAddrBytes_a, intValueBits_a) { var intI = 0; var byValue = 0; for (intI = 0; intI < intWidth_a; intI++) { byValue = (intValue_a >>> (intValueBits_a * intI)) & ((1 << intValueBits_a) - 1); gen_pushLE(arrOut_a, gen_pick(arrHdrWindow_a, byValue), intAddrBytes_a); } }
function gen_nextRand() { var lngState = m_lngRandState; lngState = (lngState ^ (lngState << 13)) >>> 0; lngState = (lngState ^ (lngState >>> 17)) >>> 0; lngState = (lngState ^ (lngState << 5)) >>> 0; m_lngRandState = lngState; return lngState; }
function gen_offset(intPtr_a, intROMLen_a, intCap_a, blnSliding_a) { var intOffset = 0; var objSpan = null; if (blnSliding_a) { objSpan = gen_regime(intROMLen_a, intCap_a); if (objSpan.wrap > 0) { intOffset = intPtr_a % (objSpan.wrap + 1); } } return intOffset; }
function gen_pick(arrWindow_a, intValue_a) { var intAddr = 0; var intLen = arrWindow_a[intValue_a].length; if (intLen > 0) { intAddr = arrWindow_a[intValue_a][gen_nextRand() % intLen]; } return intAddr; }
function gen_pushLE(arrOut_a, lngValue_a, intBytes_a) { var intI = 0; for (intI = 0; intI < intBytes_a; intI++) { arrOut_a.push((lngValue_a >>> (8 * intI)) & 0xFF); } }
function gen_readHdrValue(arrROM_a, arrBytes_a, intPos_a, intWidth_a, intAddrBytes_a, intValueBits_a) { var intValue = 0; var intI = 0; for (intI = 0; intI < intWidth_a; intI++) { intValue = intValue | (arrROM_a[gen_readLE(arrBytes_a, intPos_a + intI * intAddrBytes_a, intAddrBytes_a)] << (intValueBits_a * intI)); } return intValue; }
function gen_readLE(arrBytes_a, intPos_a, intBytes_a) { var lngValue = 0; var intI = 0; for (intI = 0; intI < intBytes_a; intI++) { lngValue = (lngValue | (arrBytes_a[intPos_a + intI] << (8 * intI))) >>> 0; } return lngValue; }
function gen_regime(intROMLen_a, intCap_a) { var intPct = Math.floor(intROMLen_a * 2 / 100); var intLimit = intCap_a + Math.floor(intCap_a * 2 / 100); var objSpan = { size: intCap_a, wrap: intCap_a }; if (intROMLen_a < intLimit) { objSpan.size = intROMLen_a - intPct; objSpan.wrap = intPct; } else if (intROMLen_a < 2 * intCap_a) { objSpan.size = intCap_a; objSpan.wrap = intROMLen_a - intCap_a; } return objSpan; }
function gen_rollingHash(arrBytes_a) { var lngHash = 0; var intPass = 0; var intI = 0; var intLast = 0; var byState = 0; var intLen = arrBytes_a.length; for (intPass = 0; intPass < 4; intPass++) { byState = 0; intLast = intLen - 1; while (intLast >= 0 && (intLast % 4) != intPass) { intLast--; } if (intLast >= 0) { byState = arrBytes_a[intLast]; for (intI = intLast - 4; intI >= 0; intI = intI - 4) { byState = byState ^ arrBytes_a[intI]; } byState = byState ^ arrBytes_a[intLast]; } lngHash = (lngHash | (byState << (8 * intPass))) >>> 0; } return lngHash; }
function gen_seed(arrROM_a, lngExtra_a) { var lngSeed = gen_romHash(arrROM_a); lngSeed = (lngSeed ^ gen_timer()) >>> 0; if (lngExtra_a != 0) { lngSeed = (lngSeed ^ lngExtra_a) >>> 0; } if (lngSeed == 0) { lngSeed = 0x9E3779B9; } return lngSeed; }
function gen_timer() { var lngTime = 0; if (typeof performance != "undefined" && performance.now) { lngTime = (performance.now() * 1000) >>> 0; } else { lngTime = Date.now() >>> 0; } return lngTime; }
function gen_unbrainless(arrBytes_a, intDir_a) { var intI = 0; var intLen = arrBytes_a.length; if (intLen > 0 && intDir_a == 1) { arrBytes_a[intLen - 1] = arrBytes_a[intLen - 1] ^ arrBytes_a[0]; for (intI = 0; intI <= intLen - 2; intI++) { arrBytes_a[intI] = arrBytes_a[intI] ^ arrBytes_a[intI + 1]; } } else if (intLen > 0 && intDir_a == 2) { arrBytes_a[0] = arrBytes_a[0] ^ arrBytes_a[intLen - 1]; for (intI = intLen - 1; intI >= 1; intI--) { arrBytes_a[intI] = arrBytes_a[intI] ^ arrBytes_a[intI - 1]; } } }
function gen_zacBytes(objArgs_a) { var arrZac = []; var intI = 0; var intLen = objArgs_a.zac.value.length; if (intLen > 0) { for (intI = 0; intI < intLen; intI++) { arrZac.push(objArgs_a.zac.value.charCodeAt(intI)); } } else { for (intI = 0; intI < objArgs_a.zac.bytes; intI++) { arrZac.push(gen_nextRand() % 256); } } return arrZac; }
function gen_zacLen(objArgs_a) { var intLen = 0; if (objArgs_a.zac.on) { intLen = objArgs_a.zac.value.length; if (intLen == 0) { intLen = objArgs_a.zac.bytes; } } return intLen; }

function gen_encode(arrROM_a, arrMessage_a, objArgs_a)
{
    var ADDRESS_SPACE = 1 << objArgs_a.elemBits;
    var intAddrBytes = objArgs_a.elemBits / 8;
    var intValueBits = objArgs_a.elemBits / 2;
    var intUnit = 16 / objArgs_a.elemBits;
    var arrOut = [];
    var arrPayload = [];
    var arrElems = [];
    var arrZac = [];
    var arrPrefix = [];
    var arrSuffix = [];
    var arrBlocks = [];
    var arrHdrWindow = [];
    var arrWindow = [];
    var intI = 0;
    var intK = 0;
    var intHeadLen = 0;
    var intPrefixLen = 0;
    var intSuffixLen = 0;
    var intBlockLen = 0;
    var intPtr = 0;
    var intOffset = 0;
    var intSize = 0;
    var intValue = 0;
    var intROMLen = arrROM_a.length;
    var intMessageLen = arrMessage_a.length;
    var lngHash = 0;
    var blnMulti = (objArgs_a.blocks == 1);
    var blnOk = true;

    m_lngRandState = gen_seed(arrROM_a, objArgs_a.seed);
    intSize = ADDRESS_SPACE;
    if (intROMLen < ADDRESS_SPACE)
    {
        intSize = intROMLen;
    }
    arrHdrWindow = gen_buildWindow(arrROM_a, 0, intSize);

    // integrity words + ZAC lead the payload (presegment placement)
    if (objArgs_a.rollingHash == 1)
    {
        gen_pushLE(arrPayload, gen_rollingHash(arrMessage_a), 4);
    }
    if (objArgs_a.crc32)
    {
        gen_pushLE(arrPayload, gen_crc32Std(arrMessage_a), 4);
    }
    if (objArgs_a.zac.on)
    {
        arrZac = gen_zacBytes(objArgs_a);
        for (intI = 0; intI < arrZac.length; intI++)
        {
            arrPayload.push(arrZac[intI]);
        }
    }
    intHeadLen = arrPayload.length;
    for (intI = 0; intI < intMessageLen; intI++)
    {
        arrPayload.push(arrMessage_a[intI]);
    }

    // payload bytes -> address elements (nibble mode: low nibble first, then high nibble)
    if (objArgs_a.elemBits == 8)
    {
        for (intI = 0; intI < arrPayload.length; intI++)
        {
            arrElems.push(arrPayload[intI] & 0x0F);
            arrElems.push((arrPayload[intI] >> 4) & 0x0F);
        }
        intHeadLen = intHeadLen * 2;
    }
    else
    {
        for (intI = 0; intI < arrPayload.length; intI++)
        {
            arrElems.push(arrPayload[intI]);
        }
    }

    // random prefix / suffix
    if (objArgs_a.prefix.on)
    {
        intPrefixLen = objArgs_a.prefix.min + (gen_nextRand() % (objArgs_a.prefix.max - objArgs_a.prefix.min + 1));
    }
    if (objArgs_a.suffix.on)
    {
        intSuffixLen = objArgs_a.suffix.min + (gen_nextRand() % (objArgs_a.suffix.max - objArgs_a.suffix.min + 1));
    }
    for (intI = 0; intI < intPrefixLen; intI++)
    {
        arrPrefix.push(gen_nextRand() % 256);
    }
    for (intI = 0; intI < intSuffixLen; intI++)
    {
        arrSuffix.push(gen_nextRand() % 256);
    }
    // rolling hash raw in the last 4 bytes of the prefix (prefix placement)
    if (objArgs_a.rollingHash == 2 && intPrefixLen >= 4)
    {
        lngHash = gen_rollingHash(arrMessage_a);
        for (intI = 0; intI < 4; intI++)
        {
            arrPrefix[intPrefixLen - 4 + intI] = (lngHash >>> (8 * intI)) & 0xFF;
        }
    }

    // plan blocks (element counts)
    if (blnMulti)
    {
        intI = 0;
        if (objArgs_a.zac.on && objArgs_a.zac.closesBlock && intHeadLen > 0)
        {
            arrBlocks.push({ start: 0, len: intHeadLen, ptr: 0, addrs: [] });
            intI = intHeadLen;
        }
        while (intI < arrElems.length)
        {
            intBlockLen = (objArgs_a.blockMin + (gen_nextRand() % (objArgs_a.blockMax - objArgs_a.blockMin + 1))) * intUnit;
            if (intBlockLen > arrElems.length - intI)
            {
                intBlockLen = arrElems.length - intI;
            }
            arrBlocks.push({ start: intI, len: intBlockLen, ptr: 0, addrs: [] });
            intI = intI + intBlockLen;
        }
        if (arrBlocks.length == 0)
        {
            arrBlocks.push({ start: 0, len: 0, ptr: 0, addrs: [] });
        }
    }
    else
    {
        arrBlocks.push({ start: 0, len: arrElems.length, ptr: 0, addrs: [] });
    }

    // encode each block at its own offset
    intSize = gen_effSize(intROMLen, ADDRESS_SPACE, objArgs_a.sliding);
    for (intK = 0; intK < arrBlocks.length; intK++)
    {
        intPtr = 0;
        if (objArgs_a.sliding)
        {
            intPtr = gen_nextRand() % ADDRESS_SPACE;
        }
        intOffset = gen_offset(intPtr, intROMLen, ADDRESS_SPACE, objArgs_a.sliding);
        arrWindow = gen_buildWindow(arrROM_a, intOffset, intSize);
        arrBlocks[intK].ptr = intPtr;
        for (intI = 0; intI < arrBlocks[intK].len; intI++)
        {
            intValue = arrElems[arrBlocks[intK].start + intI];
            if (arrWindow[intValue].length > 0)
            {
                arrBlocks[intK].addrs.push(gen_pick(arrWindow, intValue));
            }
            else
            {
                blnOk = false;
            }
        }
    }

    if (blnOk)
    {
        // FILE HEADER: [offset if sliding][block 1 size if multi][prefix len][suffix len]
        if (objArgs_a.sliding)
        {
            gen_hdrValue(arrOut, arrHdrWindow, arrBlocks[0].ptr, 2, intAddrBytes, intValueBits);
        }
        if (blnMulti)
        {
            gen_hdrValue(arrOut, arrHdrWindow, arrBlocks[0].addrs.length / intUnit, 2, intAddrBytes, intValueBits);
        }
        if (objArgs_a.prefix.on)
        {
            gen_hdrValue(arrOut, arrHdrWindow, intPrefixLen, objArgs_a.prefix.width, intAddrBytes, intValueBits);
        }
        if (objArgs_a.suffix.on)
        {
            gen_hdrValue(arrOut, arrHdrWindow, intSuffixLen, objArgs_a.suffix.width, intAddrBytes, intValueBits);
        }
        for (intI = 0; intI < intPrefixLen; intI++)
        {
            arrOut.push(arrPrefix[intI]);
        }
        for (intK = 0; intK < arrBlocks.length; intK++)
        {
            if (blnMulti)
            {
                if (intK + 1 < arrBlocks.length)
                {
                    gen_hdrValue(arrOut, arrHdrWindow, arrBlocks[intK + 1].ptr, 2, intAddrBytes, intValueBits);
                    gen_hdrValue(arrOut, arrHdrWindow, arrBlocks[intK + 1].addrs.length / intUnit, 2, intAddrBytes, intValueBits);
                }
                else
                {
                    gen_hdrValue(arrOut, arrHdrWindow, gen_nextRand() % ADDRESS_SPACE, 2, intAddrBytes, intValueBits);
                    gen_hdrValue(arrOut, arrHdrWindow, gen_nextRand() % ADDRESS_SPACE, 2, intAddrBytes, intValueBits);
                }
            }
            for (intI = 0; intI < arrBlocks[intK].addrs.length; intI++)
            {
                gen_pushLE(arrOut, arrBlocks[intK].addrs[intI], intAddrBytes);
            }
        }
        for (intI = 0; intI < intSuffixLen; intI++)
        {
            arrOut.push(arrSuffix[intI]);
        }
        gen_brainless(arrOut, objArgs_a.brainless);
    }

    return arrOut;
}

function gen_decode(arrROM_a, arrEncoded_a, objArgs_a)
{
    var ADDRESS_SPACE = 1 << objArgs_a.elemBits;
    var intAddrBytes = objArgs_a.elemBits / 8;
    var intValueBits = objArgs_a.elemBits / 2;
    var intUnit = 16 / objArgs_a.elemBits;
    var arrBytes = [];
    var arrPayload = [];
    var arrElems = [];
    var arrMessage = [];
    var intI = 0;
    var intPos = 0;
    var intPtr = 0;
    var intSize = 0;
    var intPrefixLen = 0;
    var intSuffixLen = 0;
    var intEnd = 0;
    var intOffset = 0;
    var intNextPtr = 0;
    var intNextSize = 0;
    var intHead = 0;
    var intROMLen = arrROM_a.length;
    var intEncodedLen = arrEncoded_a.length;
    var blnMulti = (objArgs_a.blocks == 1);
    var arrBody = [];
    var blnOk = true;
    var intPrefixStart = 0;
    var intCrcPos = 0;

    for (intI = 0; intI < intEncodedLen; intI++)
    {
        arrBytes.push(arrEncoded_a[intI]);
    }
    gen_unbrainless(arrBytes, objArgs_a.brainless);

    // FILE HEADER: [offset if sliding][block 1 size if multi][prefix len][suffix len]
    if (objArgs_a.sliding)
    {
        intPtr = gen_readHdrValue(arrROM_a, arrBytes, intPos, 2, intAddrBytes, intValueBits);
        intPos = intPos + 2 * intAddrBytes;
    }
    if (blnMulti)
    {
        intSize = gen_readHdrValue(arrROM_a, arrBytes, intPos, 2, intAddrBytes, intValueBits);
        intPos = intPos + 2 * intAddrBytes;
    }
    if (objArgs_a.prefix.on)
    {
        intPrefixLen = gen_readHdrValue(arrROM_a, arrBytes, intPos, objArgs_a.prefix.width, intAddrBytes, intValueBits);
        intPos = intPos + objArgs_a.prefix.width * intAddrBytes;
    }
    if (objArgs_a.suffix.on)
    {
        intSuffixLen = gen_readHdrValue(arrROM_a, arrBytes, intPos, objArgs_a.suffix.width, intAddrBytes, intValueBits);
        intPos = intPos + objArgs_a.suffix.width * intAddrBytes;
    }
    intPrefixStart = intPos;
    intPos = intPos + intPrefixLen;
    intEnd = intEncodedLen - intSuffixLen;

    intOffset = gen_offset(intPtr, intROMLen, ADDRESS_SPACE, objArgs_a.sliding);
    if (blnMulti)
    {
        while (intPos < intEnd)
        {
            intNextPtr = gen_readHdrValue(arrROM_a, arrBytes, intPos, 2, intAddrBytes, intValueBits);
            intNextSize = gen_readHdrValue(arrROM_a, arrBytes, intPos + 2 * intAddrBytes, 2, intAddrBytes, intValueBits);
            intPos = intPos + 4 * intAddrBytes;
            for (intI = 0; intI < intSize * intUnit; intI++)
            {
                arrElems.push(arrROM_a[intOffset + gen_readLE(arrBytes, intPos, intAddrBytes)]);
                intPos = intPos + intAddrBytes;
            }
            intOffset = gen_offset(intNextPtr, intROMLen, ADDRESS_SPACE, objArgs_a.sliding);
            intSize = intNextSize;
        }
    }
    else
    {
        while (intPos < intEnd)
        {
            arrElems.push(arrROM_a[intOffset + gen_readLE(arrBytes, intPos, intAddrBytes)]);
            intPos = intPos + intAddrBytes;
        }
    }

    // address elements -> payload bytes (nibble mode: low nibble first, then high nibble)
    if (objArgs_a.elemBits == 8)
    {
        for (intI = 0; intI + 1 < arrElems.length; intI = intI + 2)
        {
            arrPayload.push(arrElems[intI] | (arrElems[intI + 1] << 4));
        }
    }
    else
    {
        for (intI = 0; intI < arrElems.length; intI++)
        {
            arrPayload.push(arrElems[intI]);
        }
    }

    // strip integrity words + ZAC from the front of the payload
    if (objArgs_a.rollingHash == 1)
    {
        intHead = intHead + 4;
    }
    if (objArgs_a.crc32)
    {
        intHead = intHead + 4;
    }
    intHead = intHead + gen_zacLen(objArgs_a);
    for (intI = intHead; intI < arrPayload.length; intI++)
    {
        arrBody.push(arrPayload[intI]);
    }
    // integrity: recompute over the message and compare; a mismatch returns an empty message
    blnOk = (arrPayload.length >= intHead);
    if (objArgs_a.rollingHash == 1)
    {
        blnOk = blnOk && (gen_readLE(arrPayload, 0, 4) == gen_rollingHash(arrBody));
    }
    if (objArgs_a.rollingHash == 2 && intPrefixLen >= 4)
    {
        blnOk = blnOk && (intPrefixStart + intPrefixLen <= intEncodedLen) && (gen_readLE(arrBytes, intPrefixStart + intPrefixLen - 4, 4) == gen_rollingHash(arrBody));
    }
    if (objArgs_a.crc32)
    {
        if (objArgs_a.rollingHash == 1)
        {
            intCrcPos = 4;
        }
        blnOk = blnOk && (gen_readLE(arrPayload, intCrcPos, 4) == gen_crc32Std(arrBody));
    }
    if (blnOk)
    {
        arrMessage = arrBody;
    }

    return arrMessage;
}

// Walk an encoded file with the ROM, the same way gen_decode does, and record the framing.
// Encoder / ROM-holder side only: used for the ROM picture and "Show demo answer". The attacks never call it.
function gen_frame(arrROM_a, arrEncoded_a, objArgs_a)
{
    var ADDRESS_SPACE = 1 << objArgs_a.elemBits;
    var intAddrBytes = objArgs_a.elemBits / 8;
    var intValueBits = objArgs_a.elemBits / 2;
    var intUnit = 16 / objArgs_a.elemBits;
    var arrBytes = arrEncoded_a.slice();
    var intPos = 0, intPtr = 0, intSize = 0, intPrefixLen = 0, intSuffixLen = 0, intHdrEnd = 0, intEnd = 0;
    var intOffset = 0, intNextPtr = 0, intNextSize = 0, intStart = 0, intI = 0, intN = 0;
    var arrBlocks = [];
    var arrCells = [];
    var intROMLen = arrROM_a.length;
    var blnMulti = (objArgs_a.blocks == 1);

    gen_unbrainless(arrBytes, objArgs_a.brainless);
    if (objArgs_a.sliding) { intPtr = gen_readHdrValue(arrROM_a, arrBytes, intPos, 2, intAddrBytes, intValueBits); intPos = intPos + 2 * intAddrBytes; }
    if (blnMulti) { intSize = gen_readHdrValue(arrROM_a, arrBytes, intPos, 2, intAddrBytes, intValueBits); intPos = intPos + 2 * intAddrBytes; }
    if (objArgs_a.prefix.on) { intPrefixLen = gen_readHdrValue(arrROM_a, arrBytes, intPos, objArgs_a.prefix.width, intAddrBytes, intValueBits); intPos = intPos + objArgs_a.prefix.width * intAddrBytes; }
    if (objArgs_a.suffix.on) { intSuffixLen = gen_readHdrValue(arrROM_a, arrBytes, intPos, objArgs_a.suffix.width, intAddrBytes, intValueBits); intPos = intPos + objArgs_a.suffix.width * intAddrBytes; }
    intHdrEnd = intPos;
    intPos = intPos + intPrefixLen;
    intEnd = arrBytes.length - intSuffixLen;
    intOffset = gen_offset(intPtr, intROMLen, ADDRESS_SPACE, objArgs_a.sliding);
    if (blnMulti)
    {
        while (intPos < intEnd)
        {
            intNextPtr = gen_readHdrValue(arrROM_a, arrBytes, intPos, 2, intAddrBytes, intValueBits);
            intNextSize = gen_readHdrValue(arrROM_a, arrBytes, intPos + 2 * intAddrBytes, 2, intAddrBytes, intValueBits);
            intPos = intPos + 4 * intAddrBytes;
            intStart = intPos;
            intN = intSize * intUnit;
            for (intI = 0; intI < intN; intI++) { arrCells.push(intOffset + gen_readLE(arrBytes, intPos, intAddrBytes)); intPos = intPos + intAddrBytes; }
            arrBlocks.push({ off: intOffset, start: intStart, n: intN });
            intOffset = gen_offset(intNextPtr, intROMLen, ADDRESS_SPACE, objArgs_a.sliding);
            intSize = intNextSize;
        }
    }
    else
    {
        intStart = intPos;
        while (intPos < intEnd) { arrCells.push(intOffset + gen_readLE(arrBytes, intPos, intAddrBytes)); intPos = intPos + intAddrBytes; }
        arrBlocks.push({ off: intOffset, start: intStart, n: arrCells.length });
    }

    return { hdrEnd: intHdrEnd, prefixLen: intPrefixLen, suffixLen: intSuffixLen, blocks: arrBlocks, cells: arrCells, firstOff: (arrBlocks.length ? arrBlocks[0].off : 0) };
}
module.exports = { gen_encode: gen_encode, gen_decode: gen_decode, gen_frame: gen_frame, seedState: function(s) { m_lngRandState = s; } };
