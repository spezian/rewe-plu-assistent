// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: x0 => new Int16Array(x0),
      AC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      AD: x0 => x0.screen,
      AE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      AF: x0 => x0.wheelDeltaX,
      AG: x0 => x0.state,
      AH: (x0,x1) => x0.createEvent(x1),
      AI: x0 => x0.offsetHeight,
      AJ: () => globalThis.document,
      AK: x0 => x0.status,
      AL: (x0,x1) => x0.postMessage(x1),
      AM: (x0,x1) => { x0.transformOrigin = x1 },
      AN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      AO: (x0,x1) => x0.getContext(x1),
      B: s => printToConsole(s),
      BB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      BC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      BD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      BE: x0 => new ResizeObserver(x0),
      BF: x0 => x0.key,
      BG: (x0,x1) => x0.go(x1),
      BH: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      BI: x0 => x0.offsetWidth,
      BJ: x0 => x0.src,
      BK: x0 => x0.getReader(),
      BL: (x0,x1) => { x0.onmessage = x1 },
      BM: (x0,x1) => { x0.objectFit = x1 },
      BN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      BO: x0 => x0.height,
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: x0 => new Uint16Array(x0),
      CC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      CD: x0 => x0.tabIndex,
      CE: (x0,x1) => x0.getPropertyValue(x1),
      CF: x0 => x0.identifier,
      CG: x0 => x0.parentElement,
      CH: x0 => x0.readText(),
      CI: x0 => x0.stopPropagation(),
      CJ: (x0,x1) => x0.revokeObjectURL(x1),
      CK: x0 => x0.read(),
      CL: (x0,x1) => x0.transferFromImageBitmap(x1),
      CM: (x0,x1) => { x0.width = x1 },
      CN: (x0,x1) => { x0.onerror = x1 },
      CO: x0 => x0.width,
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: x0 => new Int32Array(x0),
      DC: (x0,x1) => x0.querySelector(x1),
      DD: (x0,x1) => x0.contains(x1),
      DE: x0 => globalThis.parseFloat(x0),
      DF: x0 => x0.touches,
      DG: (x0,x1) => x0.querySelectorAll(x1),
      DH: x0 => x0.clipboard,
      DI: x0 => x0.disabled,
      DJ: (x0,x1) => { x0.src = x1 },
      DK: x0 => x0.value,
      DL: (x0,x1) => x0.getContext(x1),
      DM: (x0,x1) => { x0.height = x1 },
      DN: (x0,x1) => x0.removeChild(x1),
      DO: x0 => x0.remove(),
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      EC: (x0,x1) => x0.item(x1),
      ED: x0 => x0.activeElement,
      EE: (x0,x1) => x0.getComputedStyle(x1),
      EF: x0 => x0.pressure,
      EG: (x0,x1) => x0.requestAnimationFrame(x1),
      EH: (x0,x1) => x0.writeText(x1),
      EI: (x0,x1) => { x0.min = x1 },
      EJ: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      EK: x0 => x0.done,
      EL: (x0,x1) => { x0.height = x1 },
      EM: x0 => x0.getSupportedConstraints(),
      EN: (x0,x1) => { x0.onload = x1 },
      EO: (x0,x1) => { x0.src = x1 },
      F: () => new Error().stack,
      FB: x0 => new Uint32Array(x0),
      FC: x0 => x0.length,
      FD: x0 => x0.parentNode,
      FE: x0 => x0.documentElement,
      FF: x0 => x0.tiltY,
      FG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FH: x0 => x0.unlock(),
      FI: (x0,x1) => { x0.max = x1 },
      FJ: x0 => x0.naturalHeight,
      FK: x0 => x0.cancel(),
      FL: (x0,x1) => { x0.width = x1 },
      FM: x0 => ({ideal: x0}),
      FN: (x0,x1) => { x0.crossOrigin = x1 },
      FO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      G: s => JSON.stringify(s),
      GB: x0 => new Float32Array(x0),
      GC: (x0,x1) => x0.querySelectorAll(x1),
      GD: x0 => x0.tagName,
      GE: x0 => x0.computedStyleMap(),
      GF: x0 => x0.tiltX,
      GG: x0 => x0.now(),
      GH: (x0,x1) => x0.lock(x1),
      GI: (x0,x1) => { x0.disabled = x1 },
      GJ: x0 => x0.naturalWidth,
      GK: x0 => x0.body,
      GL: x0 => x0.height,
      GM: (x0,x1,x2) => ({width: x0,height: x1,deviceId: x2}),
      GN: (x0,x1) => { x0.lang = x1 },
      GO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      HC: (x0,x1) => x0.getAttribute(x1),
      HD: x0 => x0.target,
      HE: (x0,x1) => x0.get(x1),
      HF: x0 => x0.pointerType,
      HG: x0 => x0.performance,
      HH: x0 => x0.orientation,
      HI: (x0,x1) => { x0.scrollLeft = x1 },
      HJ: x0 => x0.decode(),
      HK: x0 => x0.headers,
      HL: x0 => x0.width,
      HM: x0 => ({video: x0}),
      HN: (x0,x1) => { x0.defer = x1 },
      HO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Float64Array(x0),
      IC: x0 => x0.remove(),
      ID: x0 => x0.clientY,
      IE: (o, p) => p in o,
      IF: x0 => x0.pointerId,
      IG: (d, digits) => d.toFixed(digits),
      IH: (x0,x1) => x0.querySelector(x1),
      II: (x0,x1) => { x0.spellcheck = x1 },
      IJ: (x0,x1) => { x0.decoding = x1 },
      IK: x0 => x0.signal,
      IL: x0 => x0.rasterEndMilliseconds,
      IM: (x0,x1) => ({width: x0,height: x1}),
      IN: x0 => x0.videoHeight,
      IO: (x0,x1) => { x0.oncancel = x1 },
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (x0,x1) => x0.appendChild(x1),
      JD: x0 => x0.clientX,
      JE: (x0,x1) => { x0.textContent = x1 },
      JF: x0 => x0.getCoalescedEvents(),
      JG: x0 => x0.maxHeight,
      JH: (x0,x1) => { x0.title = x1 },
      JI: (x0,x1) => { x0.disabled = x1 },
      JJ: (x0,x1) => { x0.crossOrigin = x1 },
      JK: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      JL: x0 => x0.rasterStartMilliseconds,
      JM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      JN: x0 => x0.videoWidth,
      JO: (x0,x1) => { x0.onchange = x1 },
      K: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      KB: x0 => new ArrayBuffer(x0),
      KC: (x0,x1) => x0.append(x1),
      KD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      KE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      KF: (x0,x1) => x0.getModifierState(x1),
      KG: x0 => x0.maxWidth,
      KH: (x0,x1) => x0.vibrate(x1),
      KI: (a, i) => a.splice(i, 1),
      KJ: (x0,x1) => x0.createObjectURL(x1),
      KK: () => new FileReader(),
      KL: x0 => x0.imageBitmaps,
      KM: (x0,x1) => x0.getUserMedia(x1),
      KN: x0 => x0.stream,
      KO: x0 => x0.type,
      L: o => o === undefined,
      LB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      LC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      LD: x0 => x0.getBoundingClientRect(),
      LE: x0 => x0.matches,
      LF: s => s.trimLeft(),
      LG: x0 => x0.minHeight,
      LH: x0 => x0.arrayBuffer(),
      LI: a => a.pop(),
      LJ: x0 => x0.URL,
      LK: (x0,x1) => x0.readAsArrayBuffer(x1),
      LL: x0 => x0.canvasKitMaximumSurfaces,
      LM: x0 => x0.deviceId,
      LN: x0 => x0.play(),
      LO: x0 => x0.lastModified,
      M: o => String(o),
      MB: (x0,x1,x2) => new DataView(x0,x1,x2),
      MC: x0 => x0.style,
      MD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      ME: (x0,x1) => x0.matchMedia(x1),
      MF: (x0,x1) => x0[x1],
      MG: x0 => x0.minWidth,
      MH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      MI: (map, o, v) => map.set(o, v),
      MJ: x0 => new Blob(x0),
      MK: x0 => x0.result,
      ML: x0 => x0.nextSibling,
      MM: x0 => x0.getCapabilities(),
      MN: x0 => x0.paused,
      MO: x0 => x0.name,
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: (o, p) => o[p],
      NC: x0 => x0.debugShowSemanticsNodes,
      ND: s => new Date(s * 1000).getTimezoneOffset() * 60,
      NE: x0 => x0.matches,
      NF: x0 => x0.index,
      NG: (x0,x1) => x0.removeProperty(x1),
      NH: x0 => x0.status,
      NI: (map, o) => map.get(o),
      NJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      NK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NL: (x0,x1) => x0.debug(x1),
      NM: () => ({}),
      NN: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      NO: (x0,x1) => x0.item(x1),
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      OC: o => o,
      OD: Date.now,
      OE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      OF: s => s.toUpperCase(),
      OG: (x0,x1) => x0.add(x1),
      OH: (x0,x1) => x0.fetch(x1),
      OI: () => new WeakMap(),
      OJ: x0 => new window.ImageDecoder(x0),
      OK: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      OL: x0 => x0.hostElement,
      OM: (x0,x1) => x0.applyConstraints(x1),
      ON: (x0,x1,x2,x3,x4) => x0.getImageData(x1,x2,x3,x4),
      OO: x0 => x0.length,
      P: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      PC: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      PD: (handle) => clearTimeout(handle),
      PE: f => f.dartFunction,
      PF: x0 => x0.pop(),
      PG: x0 => x0.data,
      PH: x0 => x0.content,
      PI: x0 => new WeakRef(x0),
      PJ: x0 => x0.name,
      PK: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      PL: x0 => x0.location,
      PM: (x0,x1) => { x0.whiteBalanceMode = x1 },
      PN: (x0,x1,x2) => x0.readBarcodes(x1,x2),
      PO: x0 => x0.files,
      Q: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      QB: o => o.byteOffset,
      QC: (x0,x1) => x0.warn(x1),
      QD: (a, l) => a.length = l,
      QE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QF: x0 => x0.flags,
      QG: (x0,x1) => { x0.scrollTop = x1 },
      QH: x0 => x0.document,
      QI: x0 => x0.deref(),
      QJ: x0 => x0.repetitionCount,
      QK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QL: (x0,x1) => x0.getModifierState(x1),
      QM: x0 => x0.whiteBalanceMode,
      QN: x0 => x0.text,
      QO: x0 => x0.target,
      R: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      RB: o => o.buffer,
      RC: x0 => x0.console,
      RD: (x0,x1) => x0.closest(x1),
      RE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      RF: (a, s) => a.join(s),
      RG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      RH: () => typeof dartUseDateNowForTicks !== "undefined",
      RI: () => globalThis.WeakRef,
      RJ: x0 => x0.frameCount,
      RK: () => new XMLHttpRequest(),
      RL: x0 => x0.metaKey,
      RM: (x0,x1) => { x0.exposureMode = x1 },
      RN: x0 => x0.format,
      RO: (x0,x1) => x0.replaceChildren(x1),
      S: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SB: Function.prototype.call.bind(DataView.prototype.getUint8),
      SC: () => globalThis.window,
      SD: x0 => x0.bottom,
      SE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      SF: (x0,x1) => x0.error(x1),
      SG: (x0,x1) => { x0.value = x1 },
      SH: () => Date.now(),
      SI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      SJ: x0 => x0.selectedTrack,
      SK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      SL: x0 => x0.altKey,
      SM: x0 => x0.exposureMode,
      SN: x0 => x0.bytes,
      SO: x0 => x0.click(),
      T: x0 => new Promise(x0),
      TB: (b, o) => new DataView(b, o),
      TC: (o, c) => o instanceof c,
      TD: x0 => x0.top,
      TE: (o, i) => o[i],
      TF: () => globalThis.console,
      TG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      TH: () => 1000 * performance.now(),
      TI: (a, s, e) => a.slice(s, e),
      TJ: x0 => x0.completed,
      TK: x0 => x0.send(),
      TL: x0 => x0.ctrlKey,
      TM: (x0,x1) => { x0.focusMode = x1 },
      TN: x0 => x0.y,
      TO: (x0,x1,x2) => x0.setAttribute(x1,x2),
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: (b, o, l) => new DataView(b, o, l),
      UC: (x0,x1) => x0.exec(x1),
      UD: x0 => x0.right,
      UE: o => o.length,
      UF: s => s.trimRight(),
      UG: (x0,x1) => { x0.value = x1 },
      UH: x0 => new Uint8Array(x0),
      UI: (x0,x1) => x0.error(x1),
      UJ: x0 => x0.ready,
      UK: x0 => x0.type,
      UL: x0 => x0.isComposing,
      UM: x0 => x0.focusMode,
      UN: x0 => x0.x,
      UO: (x0,x1) => { x0.accept = x1 },
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      VC: x0 => x0.length,
      VD: x0 => x0.left,
      VE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      VF: x0 => x0.blur(),
      VG: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      VH: (x0,x1,x2) => x0.slice(x1,x2),
      VI: () => globalThis.console,
      VJ: x0 => x0.tracks,
      VK: x0 => x0.response,
      VL: x0 => x0.code,
      VM: x0 => x0.enumerateDevices(),
      VN: x0 => x0.bottomLeft,
      VO: (x0,x1) => { x0.multiple = x1 },
      W: x0 => new Array(x0),
      WB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      WC: (x0,x1) => { x0.lastIndex = x1 },
      WD: x0 => x0.clientY,
      WE: x0 => x0.language,
      WF: x0 => x0.button,
      WG: x0 => x0.value,
      WH: (x0,x1) => x0.decode(x1),
      WI: () => new MessageChannel(),
      WJ: x0 => x0.close(),
      WK: (x0,x1) => { x0.responseType = x1 },
      WL: x0 => x0.repeat,
      WM: x0 => x0.deviceId,
      WN: x0 => x0.bottomRight,
      WO: (x0,x1) => { x0.type = x1 },
      X: o => [o],
      XB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      XC: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      XD: x0 => x0.clientX,
      XE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      XF: x0 => x0.innerHeight,
      XG: x0 => x0.selectionDirection,
      XH: (x0,x1) => x0.adoptText(x1),
      XI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      XK: x0 => x0.vendor,
      XL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XM: x0 => x0.kind,
      XN: x0 => x0.topRight,
      XO: (o, a) => o + a,
      Y: (o0, o1) => [o0, o1],
      YB: (t, s) => t.set(s),
      YC: o => o instanceof RegExp,
      YD: x0 => x0.changedTouches,
      YE: () => globalThis.window.FinalizationRegistry,
      YF: x0 => x0.innerWidth,
      YG: x0 => x0.selectionStart,
      YH: x0 => x0.first(),
      YI: x0 => x0.port2,
      YJ: (x0,x1) => x0.decode(x1),
      YK: x0 => x0.navigator,
      YL: x0 => globalThis.Wakelock.toggle(x0),
      YM: x0 => x0.mediaDevices,
      YN: x0 => x0.topLeft,
      YO: x0 => x0.children,
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      ZC: (string, times) => string.repeat(times),
      ZD: x0 => x0.offsetY,
      ZE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      ZF: x0 => x0.height,
      ZG: x0 => x0.selectionEnd,
      ZH: x0 => x0.next(),
      ZI: (x0,x1) => { x0.onmessage = x1 },
      ZJ: x0 => x0.displayHeight,
      ZK: () => globalThis.window,
      ZL: (x0,x1) => x0.appendChild(x1),
      ZM: x0 => x0.facingMode,
      ZN: x0 => x0.position,
      ZO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      aC: x0 => x0.dotAll,
      aD: x0 => x0.offsetX,
      aE: x0 => new window.FinalizationRegistry(x0),
      aF: x0 => x0.width,
      aG: x0 => x0.value,
      aH: x0 => x0.current(),
      aI: x0 => globalThis.Object.keys(x0),
      aJ: x0 => x0.displayWidth,
      aK: x0 => new Blob(x0),
      aL: x0 => x0.id,
      aM: x0 => x0.mediaDevices,
      aN: x0 => x0.isValid,
      aO: (x0,x1,x2) => x0.addEventListener(x1,x2),
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      bC: x0 => x0.unicode,
      bD: x0 => x0.type,
      bE: (x0,x1) => x0.unregister(x1),
      bF: x0 => x0.clientHeight,
      bG: x0 => x0.selectionDirection,
      bH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      bI: x0 => x0.length,
      bJ: x0 => x0.duration,
      bK: x0 => globalThis.fetch(x0),
      bL: (x0,x1) => x0.createElement(x1),
      bM: () => globalThis.BarcodeDetector.getSupportedFormats(),
      bN: (x0,x1,x2,x3) => ({formats: x0,tryHarder: x1,tryRotate: x2,tryInvert: x3}),
      bO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      c: o => o,
      cB: Function.prototype.call.bind(DataView.prototype.getUint32),
      cC: x0 => x0.ignoreCase,
      cD: x0 => x0.maxTouchPoints,
      cE: (x0,x1) => x0.contains(x1),
      cF: x0 => x0.clientWidth,
      cG: x0 => x0.selectionStart,
      cH: x0 => x0.v8BreakIterator,
      cI: (o, t) => typeof o === t,
      cJ: x0 => x0.image,
      cK: x0 => x0.arrayBuffer(),
      cL: (x0,x1) => { x0.id = x1 },
      cM: (x0,x1) => x0.call(x1),
      cN: (x0,x1,x2) => ({tryHarder: x0,tryRotate: x1,tryInvert: x2}),
      cO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      d: (o, p) => o[p],
      dB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      dC: x0 => x0.multiline,
      dD: x0 => x0.platform,
      dE: (s) => +s,
      dF: (x0,x1) => { x0.content = x1 },
      dG: x0 => x0.selectionEnd,
      dH: () => globalThis.Intl,
      dI: x0 => x0.data,
      dJ: () => globalThis.window.ImageDecoder,
      dK: x0 => x0.size,
      dL: (x0,x1) => { x0.src = x1 },
      dM: x0 => x0.reset,
      dN: () => globalThis.ZXingWASM,
      dO: x0 => x0.firstChild,
      e: () => globalThis,
      eB: Function.prototype.call.bind(DataView.prototype.getInt32),
      eC: (string, token) => string.split(token),
      eD: x0 => x0.body,
      eE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      eF: (x0,x1) => { x0.name = x1 },
      eG: x0 => x0.keyCode,
      eH: (x0,x1) => x0.segment(x1),
      eI: x0 => x0.port1,
      eJ: x0 => x0.decode(),
      eK: () => new Array(),
      eL: (x0,x1) => { x0.async = x1 },
      eM: x0 => x0.stopContinuousDecode,
      eN: (x0,x1) => { x0.height = x1 },
      eO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      f: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      fC: o => o instanceof Array,
      fD: () => globalThis.document,
      fE: s => s.trim(),
      fF: x0 => x0.head,
      fG: (x0,x1) => x0.scrollIntoView(x1),
      fH: x0 => x0.index,
      fI: (x0,x1) => new SharedWorker(x0,x1),
      fJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      fK: (x0,x1) => new WebSocket(x0,x1),
      fL: (x0,x1) => { x0.charset = x1 },
      fM: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      fN: (x0,x1) => { x0.width = x1 },
      fO: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: o => o instanceof Uint16Array,
      gC: (a, i) => a[i],
      gD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      gE: x0 => x0.classList,
      gF: (x0,x1) => x0.removeChild(x1),
      gG: x0 => x0.multiViewEnabled,
      gH: x0 => x0.next(),
      gI: x0 => new Worker(x0),
      gJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gK: x0 => x0.reason,
      gL: (x0,x1) => { x0.type = x1 },
      gM: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      gN: x0 => x0.height,
      gO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      h: (x0,x1) => ({addView: x0,removeView: x1}),
      hB: Function.prototype.call.bind(DataView.prototype.getUint16),
      hC: a => a.length,
      hD: x0 => x0.hasFocus(),
      hE: x0 => x0.preventDefault(),
      hF: x0 => x0.firstChild,
      hG: (x0,x1) => x0.replaceWith(x1),
      hH: x0 => x0.value,
      hI: (x0,x1,x2) => x0.postMessage(x1,x2),
      hJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      hK: x0 => x0.code,
      hL: (x0,x1) => x0.querySelector(x1),
      hM: x0 => x0.text,
      hN: x0 => x0.width,
      hO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      i: (l, r) => l === r,
      iB: o => o instanceof Int16Array,
      iC: (x0,x1) => x0.test(x1),
      iD: x0 => x0.relatedTarget,
      iE: x0 => x0.parent,
      iF: x0 => x0.viewConstraints,
      iG: (x0,x1) => { x0.type = x1 },
      iH: x0 => x0.done,
      iI: (o, p, v) => o[p] = v,
      iJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iK: (x0,x1,x2) => x0.close(x1,x2),
      iL: x0 => x0.head,
      iM: x0 => x0.barcodeFormat,
      iN: (x0,x1) => { x0.srcObject = x1 },
      iO: x0 => ({type: x0}),
      j: x0 => x0.random(),
      jB: Function.prototype.call.bind(DataView.prototype.getInt16),
      jC: x0 => x0.userAgent,
      jD: x0 => x0.shiftKey,
      jE: x0 => x0.timeStamp,
      jF: x0 => x0.hostElement,
      jG: (x0,x1) => { x0.className = x1 },
      jH: (o, m, a) => o[m].apply(o, a),
      jI: (x0,x1) => { x0.onerror = x1 },
      jJ: x0 => x0.send(),
      jK: (x0,x1) => x0.close(x1),
      jL: () => globalThis.document,
      jM: x0 => x0.rawBytes,
      jN: x0 => ({willReadFrequently: x0}),
      jO: (x0,x1) => new Blob(x0,x1),
      k: o => o,
      kB: o => o instanceof Uint8ClampedArray,
      kC: x0 => x0.navigator,
      kD: (decoder, codeUnits) => decoder.decode(codeUnits),
      kE: (x0,x1) => x0.hasAttribute(x1),
      kF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      kG: (x0,x1) => { x0.tabIndex = x1 },
      kH: x0 => x0.iterator,
      kI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      kJ: x0 => x0.status,
      kK: x0 => x0.close(),
      kL: x0 => x0.userAgent,
      kM: x0 => x0.y,
      kN: (x0,x1,x2) => x0.getContext(x1,x2),
      kO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      l: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      lB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      lC: Function.prototype.call.bind(String.prototype.toLowerCase),
      lD: () => new TextDecoder("utf-8", {fatal: true}),
      lE: x0 => x0.buttons,
      lF: x0 => ({runApp: x0}),
      lG: (x0,x1) => { x0.name = x1 },
      lH: () => globalThis.Symbol,
      lI: (x0,x1,x2) => x0.postMessage(x1,x2),
      lJ: x0 => x0.response,
      lK: (x0,x1) => x0.send(x1),
      lL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      lM: x0 => x0.x,
      lN: () => new BarcodeDetector(),
      lO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      m: () => globalThis.Math,
      mB: Function.prototype.call.bind(DataView.prototype.setInt32),
      mC: Object.is,
      mD: () => new TextDecoder("utf-8", {fatal: false}),
      mE: x0 => x0.ctrlKey,
      mF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      mG: (x0,x1) => { x0.placeholder = x1 },
      mH: (x0,x1) => new Intl.Segmenter(x0,x1),
      mI: x0 => x0.port,
      mJ: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      mK: x0 => x0.readyState,
      mL: (x0,x1) => x0.key(x1),
      mM: x0 => x0.resultPoints,
      mN: x0 => ({formats: x0}),
      mO: (x0,x1) => { x0.display = x1 },
      n: (x0,x1) => x0.prepend(x1),
      nB: Function.prototype.call.bind(DataView.prototype.setUint32),
      nC: x0 => x0.vendor,
      nD: (a, i, v) => a[i] = v,
      nE: x0 => x0.y,
      nF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      nG: (x0,x1) => { x0.autocomplete = x1 },
      nH: x0 => x0.Segmenter,
      nI: (x0,x1) => { x0.onerror = x1 },
      nJ: (x0,x1) => { x0.responseType = x1 },
      nK: (x0,x1) => { x0.binaryType = x1 },
      nL: x0 => x0.length,
      nM: x0 => x0.message,
      nN: x0 => new BarcodeDetector(x0),
      nO: (x0,x1) => { x0.draggable = x1 },
      o: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      oB: Function.prototype.call.bind(DataView.prototype.setInt16),
      oC: (x0,x1) => x0.createTextNode(x1),
      oD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      oE: x0 => x0.x,
      oF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      oG: (x0,x1) => { x0.name = x1 },
      oH: x0 => x0.buffer,
      oI: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      oJ: () => new XMLHttpRequest(),
      oK: (a, l) => a.length = l,
      oL: (x0,x1) => { x0.transform = x1 },
      oM: x0 => x0.videoElement,
      oN: (x0,x1) => x0.detect(x1),
      oO: x0 => x0.length,
      p: b => !!b,
      pB: Function.prototype.call.bind(DataView.prototype.setUint16),
      pC: (x0,x1) => { x0.id = x1 },
      pD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      pE: x0 => x0.scrollTop,
      pF: o => o.byteLength,
      pG: (x0,x1) => { x0.placeholder = x1 },
      pH: x0 => x0.wasmMemory,
      pI: (x0,x1) => x0.getRandomValues(x1),
      pJ: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      pK: (x0,x1) => x0.getItem(x1),
      pL: x0 => x0.style,
      pM: x0 => x0.decodeContinuously,
      pN: x0 => x0.rawValue,
      pO: x0 => x0.getReader(),
      q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qB: Function.prototype.call.bind(DataView.prototype.setUint8),
      qC: (x0,x1) => { x0.nonce = x1 },
      qD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      qE: x0 => x0.offsetTop,
      qF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      qG: (x0,x1) => { x0.action = x1 },
      qH: () => globalThis.window._flutter_skwasmInstance,
      qI: () => globalThis.crypto,
      qJ: x0 => x0.abort(),
      qK: x0 => x0.localStorage,
      qL: x0 => x0.getVideoTracks(),
      qM: (x0,x1) => new ZXing.BrowserMultiFormatReader(x0,x1),
      qN: x0 => x0.format,
      qO: x0 => x0.value,
      r: (x0,x1) => x0.focus(x1),
      rB: Function.prototype.call.bind(DataView.prototype.setInt8),
      rC: x0 => x0.nonce,
      rD: x0 => x0.visibilityState,
      rE: x0 => x0.scrollLeft,
      rF: x0 => x0.history,
      rG: (x0,x1) => { x0.method = x1 },
      rH: () => new TextDecoder(),
      rI: l => new DataView(new ArrayBuffer(l)),
      rJ: () => new AbortController(),
      rK: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      rL: x0 => x0.getSettings(),
      rM: (x0,x1) => ({width: x0,height: x1}),
      rN: x0 => x0.y,
      rO: x0 => x0.done,
      s: () => ({}),
      sB: Function.prototype.call.bind(DataView.prototype.getInt8),
      sC: () => globalThis.window.flutterConfiguration,
      sD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      sE: x0 => x0.offsetLeft,
      sF: x0 => x0.search,
      sG: (x0,x1) => { x0.noValidate = x1 },
      sH: x0 => x0.debugSkipFontRetryDelay,
      sI: x0 => x0.naturalHeight,
      sJ: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      sK: x0 => x0.history,
      sL: x0 => x0.facingMode,
      sM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      sN: x0 => x0.x,
      sO: x0 => x0.read(),
      t: (o, p, v) => o[p] = v,
      tB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      tC: (x0,x1) => x0.attachShadow(x1),
      tD: x0 => x0.disconnect(),
      tE: x0 => x0.offsetParent,
      tF: x0 => x0.location,
      tG: (x0,x1) => x0.removeAttribute(x1),
      tH: (x0,x1,x2) => x0.set(x1,x2),
      tI: x0 => x0.naturalWidth,
      tJ: (x0,x1) => globalThis.fetch(x0,x1),
      tK: x0 => x0.href,
      tL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tM: x0 => x0.facingMode,
      tN: x0 => x0.cornerPoints,
      tO: x0 => x0.body,
      u: () => [],
      uB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      uC: (x0,x1) => x0.createElement(x1),
      uD: x0 => new Intl.Locale(x0),
      uE: (o, p, r) => o.replace(p, () => r),
      uF: x0 => x0.pathname,
      uG: x0 => x0.isConnected,
      uH: x0 => x0.fontFallbackBaseUrl,
      uI: (x0,x1) => x0.createElement(x1),
      uJ: (x0,x1) => x0.get(x1),
      uK: x0 => x0.location,
      uL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uM: x0 => x0.height,
      uN: x0 => x0.body,
      uO: (x0,x1) => new OffscreenCanvas(x0,x1),
      v: (a, i) => a.push(i),
      vB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      vC: x0 => x0.scale,
      vD: x0 => x0.region,
      vE: (o, p, r) => o.replaceAll(p, () => r),
      vF: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      vG: x0 => x0.click(),
      vH: (handle) => clearInterval(handle),
      vI: (x0,x1) => { x0.pointerEvents = x1 },
      vJ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      vK: (x0,x1) => x0.removeItem(x1),
      vL: (x0,x1) => x0.append(x1),
      vM: x0 => x0.width,
      vN: x0 => globalThis.URL.revokeObjectURL(x0),
      vO: x0 => x0.assetBase,
      w: x0 => new Int8Array(x0),
      wB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      wC: x0 => x0.visualViewport,
      wD: x0 => x0.script,
      wE: x0 => x0.deltaMode,
      wF: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      wG: (x0,x1) => x0.getElementsByClassName(x1),
      wH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      wI: (x0,x1) => { x0.height = x1 },
      wJ: (x0,x1) => x0.forEach(x1),
      wK: (x0,x1,x2) => x0.setItem(x1,x2),
      wL: (x0,x1) => { x0.onpause = x1 },
      wM: x0 => x0.attachStreamToVideo,
      wN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wO: x0 => x0.loader,
      x: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      xC: x0 => x0.devicePixelRatio,
      xD: x0 => x0.language,
      xE: x0 => x0.deltaY,
      xF: o => Object.keys(o),
      xG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      xH: () => Date.now(),
      xI: (x0,x1) => { x0.width = x1 },
      xJ: x0 => x0.name,
      xK: x0 => new BroadcastChannel(x0),
      xL: (x0,x1) => { x0.onplay = x1 },
      xM: () => new Map(),
      xN: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      xO: () => globalThis._flutter,
      y: x0 => new Uint8Array(x0),
      yB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      yC: x0 => x0.height,
      yD: x0 => x0.languages,
      yE: x0 => x0.deltaX,
      yF: x0 => x0.state,
      yG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      yH: (x0,x1,x2) => x0.insertBefore(x1,x2),
      yI: x0 => x0.style,
      yJ: x0 => x0.statusText,
      yK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      yL: (x0,x1) => { x0.controls = x1 },
      yM: (x0,x1,x2) => x0.set(x1,x2),
      yN: x0 => globalThis.URL.createObjectURL(x0),
      z: x0 => new Uint8ClampedArray(x0),
      zB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      zC: x0 => x0.width,
      zD: (x0,x1) => x0.observe(x1),
      zE: x0 => x0.wheelDeltaY,
      zF: x0 => x0.hash,
      zG: (x0,x1) => x0.dispatchEvent(x1),
      zH: x0 => x0.id,
      zI: (x0,x1) => { x0.src = x1 },
      zJ: x0 => x0.url,
      zK: x0 => x0.close(),
      zL: (x0,x1) => { x0.pointerEvents = x1 },
      zM: (x0,x1) => x0.querySelector(x1),
      zN: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
