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
      AE: x0 => new ResizeObserver(x0),
      AF: x0 => x0.key,
      AG: x0 => x0.parentElement,
      AH: x0 => x0.readText(),
      AI: x0 => x0.stopPropagation(),
      AJ: x0 => x0.close(),
      AK: x0 => x0.getReader(),
      AL: (x0,x1) => { x0.height = x1 },
      AM: x0 => x0.getSupportedConstraints(),
      AN: (x0,x1) => { x0.onload = x1 },
      AO: x0 => x0.remove(),
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
      BE: (x0,x1) => x0.getPropertyValue(x1),
      BF: x0 => x0.identifier,
      BG: (x0,x1) => x0.querySelectorAll(x1),
      BH: x0 => x0.clipboard,
      BI: x0 => x0.disabled,
      BJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      BK: x0 => x0.read(),
      BL: (x0,x1) => { x0.width = x1 },
      BM: x0 => ({ideal: x0}),
      BN: (x0,x1) => { x0.crossOrigin = x1 },
      BO: (x0,x1) => { x0.src = x1 },
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: x0 => new Uint16Array(x0),
      CC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      CD: x0 => x0.tabIndex,
      CE: x0 => globalThis.parseFloat(x0),
      CF: x0 => x0.touches,
      CG: (x0,x1) => x0.requestAnimationFrame(x1),
      CH: (x0,x1) => x0.writeText(x1),
      CI: (x0,x1) => { x0.min = x1 },
      CJ: (x0,x1) => x0.decode(x1),
      CK: x0 => x0.value,
      CL: x0 => x0.height,
      CM: (x0,x1,x2) => ({width: x0,height: x1,deviceId: x2}),
      CN: (x0,x1) => { x0.lang = x1 },
      CO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: x0 => new Int32Array(x0),
      DC: (x0,x1) => x0.querySelector(x1),
      DD: (x0,x1) => x0.contains(x1),
      DE: (x0,x1) => x0.getComputedStyle(x1),
      DF: x0 => x0.pressure,
      DG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DH: x0 => x0.unlock(),
      DI: (x0,x1) => { x0.max = x1 },
      DJ: x0 => x0.displayHeight,
      DK: x0 => x0.done,
      DL: x0 => x0.width,
      DM: x0 => ({video: x0}),
      DN: (x0,x1) => { x0.defer = x1 },
      DO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
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
      EE: x0 => x0.documentElement,
      EF: x0 => x0.tiltY,
      EG: x0 => x0.now(),
      EH: (x0,x1) => x0.lock(x1),
      EI: (x0,x1) => { x0.disabled = x1 },
      EJ: x0 => x0.displayWidth,
      EK: x0 => x0.cancel(),
      EL: x0 => x0.rasterEndMilliseconds,
      EM: (x0,x1) => ({width: x0,height: x1}),
      EN: x0 => x0.videoHeight,
      EO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      F: () => new Error().stack,
      FB: x0 => new Uint32Array(x0),
      FC: x0 => x0.length,
      FD: x0 => x0.parentNode,
      FE: x0 => x0.computedStyleMap(),
      FF: x0 => x0.tiltX,
      FG: x0 => x0.performance,
      FH: x0 => x0.orientation,
      FI: (x0,x1) => { x0.scrollLeft = x1 },
      FJ: x0 => x0.duration,
      FK: x0 => x0.body,
      FL: x0 => x0.rasterStartMilliseconds,
      FM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      FN: x0 => x0.videoWidth,
      FO: (x0,x1) => { x0.oncancel = x1 },
      G: s => JSON.stringify(s),
      GB: x0 => new Float32Array(x0),
      GC: (x0,x1) => x0.querySelectorAll(x1),
      GD: x0 => x0.tagName,
      GE: (x0,x1) => x0.get(x1),
      GF: x0 => x0.pointerType,
      GG: (d, digits) => d.toFixed(digits),
      GH: (x0,x1) => x0.querySelector(x1),
      GI: (x0,x1) => { x0.spellcheck = x1 },
      GJ: x0 => x0.image,
      GK: x0 => x0.headers,
      GL: x0 => x0.imageBitmaps,
      GM: (x0,x1) => x0.getUserMedia(x1),
      GN: x0 => x0.stream,
      GO: (x0,x1) => { x0.onchange = x1 },
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      HC: (x0,x1) => x0.getAttribute(x1),
      HD: x0 => x0.target,
      HE: (o, p) => p in o,
      HF: x0 => x0.pointerId,
      HG: x0 => x0.maxHeight,
      HH: (x0,x1) => { x0.title = x1 },
      HI: (x0,x1) => { x0.disabled = x1 },
      HJ: () => globalThis.window.ImageDecoder,
      HK: x0 => x0.signal,
      HL: x0 => x0.canvasKitMaximumSurfaces,
      HM: x0 => x0.deviceId,
      HN: x0 => x0.play(),
      HO: x0 => x0.type,
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Float64Array(x0),
      IC: x0 => x0.remove(),
      ID: x0 => x0.clientY,
      IE: (x0,x1) => { x0.textContent = x1 },
      IF: x0 => x0.getCoalescedEvents(),
      IG: x0 => x0.maxWidth,
      IH: (x0,x1) => x0.vibrate(x1),
      II: (a, i) => a.splice(i, 1),
      IJ: x0 => x0.decode(),
      IK: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      IL: x0 => x0.nextSibling,
      IM: x0 => x0.getCapabilities(),
      IN: x0 => x0.paused,
      IO: x0 => x0.lastModified,
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (x0,x1) => x0.appendChild(x1),
      JD: x0 => x0.clientX,
      JE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JF: (x0,x1) => x0.getModifierState(x1),
      JG: x0 => x0.minHeight,
      JH: x0 => x0.arrayBuffer(),
      JI: (a, l) => a.length = l,
      JJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      JK: x0 => x0.pop(),
      JL: (x0,x1) => x0.debug(x1),
      JM: () => ({}),
      JN: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      JO: x0 => x0.name,
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
      KE: x0 => x0.matches,
      KF: s => s.trimLeft(),
      KG: x0 => x0.minWidth,
      KH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      KI: a => a.pop(),
      KJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      KK: () => new FileReader(),
      KL: x0 => x0.hostElement,
      KM: (x0,x1) => x0.applyConstraints(x1),
      KN: (x0,x1,x2,x3,x4) => x0.getImageData(x1,x2,x3,x4),
      KO: (x0,x1) => x0.item(x1),
      L: o => o === undefined,
      LB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      LC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      LD: x0 => x0.getBoundingClientRect(),
      LE: (x0,x1) => x0.matchMedia(x1),
      LF: (x0,x1) => x0[x1],
      LG: (x0,x1) => x0.removeProperty(x1),
      LH: x0 => x0.status,
      LI: (map, o, v) => map.set(o, v),
      LJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      LK: (x0,x1) => x0.readAsArrayBuffer(x1),
      LL: x0 => x0.location,
      LM: (x0,x1) => { x0.whiteBalanceMode = x1 },
      LN: (x0,x1,x2) => x0.readBarcodes(x1,x2),
      LO: x0 => x0.length,
      M: o => String(o),
      MB: (x0,x1,x2) => new DataView(x0,x1,x2),
      MC: x0 => x0.style,
      MD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      ME: x0 => x0.matches,
      MF: x0 => x0.index,
      MG: (x0,x1) => x0.add(x1),
      MH: (x0,x1) => x0.fetch(x1),
      MI: (map, o) => map.get(o),
      MJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MK: x0 => x0.result,
      ML: (x0,x1) => x0.getModifierState(x1),
      MM: x0 => x0.whiteBalanceMode,
      MN: x0 => x0.text,
      MO: x0 => x0.files,
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: (o, p) => o[p],
      NC: x0 => x0.debugShowSemanticsNodes,
      ND: s => new Date(s * 1000).getTimezoneOffset() * 60,
      NE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      NF: s => s.toUpperCase(),
      NG: x0 => x0.data,
      NH: x0 => x0.content,
      NI: () => new WeakMap(),
      NJ: x0 => x0.send(),
      NK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NL: x0 => x0.metaKey,
      NM: (x0,x1) => { x0.exposureMode = x1 },
      NN: x0 => x0.format,
      NO: x0 => x0.target,
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      OC: o => o,
      OD: Date.now,
      OE: f => f.dartFunction,
      OF: x0 => x0.flags,
      OG: (x0,x1) => { x0.scrollTop = x1 },
      OH: x0 => x0.document,
      OI: x0 => new WeakRef(x0),
      OJ: x0 => x0.status,
      OK: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      OL: x0 => x0.altKey,
      OM: x0 => x0.exposureMode,
      ON: x0 => x0.bytes,
      OO: (x0,x1) => x0.replaceChildren(x1),
      P: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      PC: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      PD: (handle) => clearTimeout(handle),
      PE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PF: (a, s) => a.join(s),
      PG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      PH: () => typeof dartUseDateNowForTicks !== "undefined",
      PI: x0 => x0.deref(),
      PJ: x0 => x0.response,
      PK: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      PL: x0 => x0.ctrlKey,
      PM: (x0,x1) => { x0.focusMode = x1 },
      PN: x0 => x0.y,
      PO: x0 => x0.click(),
      Q: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      QB: o => o.byteOffset,
      QC: (x0,x1) => x0.warn(x1),
      QD: (x0,x1) => x0.closest(x1),
      QE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      QF: (x0,x1) => x0.error(x1),
      QG: (x0,x1) => { x0.value = x1 },
      QH: () => Date.now(),
      QI: () => globalThis.WeakRef,
      QJ: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      QK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QL: x0 => x0.isComposing,
      QM: x0 => x0.focusMode,
      QN: x0 => x0.x,
      QO: (x0,x1,x2) => x0.setAttribute(x1,x2),
      R: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      RB: o => o.buffer,
      RC: x0 => x0.console,
      RD: x0 => x0.bottom,
      RE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      RF: () => globalThis.console,
      RG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      RH: () => 1000 * performance.now(),
      RI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      RJ: (x0,x1) => { x0.responseType = x1 },
      RK: () => new XMLHttpRequest(),
      RL: x0 => x0.code,
      RM: x0 => x0.enumerateDevices(),
      RN: x0 => x0.bottomLeft,
      RO: (x0,x1) => { x0.accept = x1 },
      S: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SB: Function.prototype.call.bind(DataView.prototype.getUint8),
      SC: () => globalThis.window,
      SD: x0 => x0.top,
      SE: (o, i) => o[i],
      SF: s => s.trimRight(),
      SG: (x0,x1) => { x0.value = x1 },
      SH: x0 => new Uint8Array(x0),
      SI: (a, s, e) => a.slice(s, e),
      SJ: () => new XMLHttpRequest(),
      SK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      SL: x0 => x0.repeat,
      SM: x0 => x0.deviceId,
      SN: x0 => x0.bottomRight,
      SO: (x0,x1) => { x0.multiple = x1 },
      T: x0 => new Promise(x0),
      TB: (b, o) => new DataView(b, o),
      TC: (o, c) => o instanceof c,
      TD: x0 => x0.right,
      TE: o => o.length,
      TF: x0 => x0.blur(),
      TG: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      TH: (x0,x1,x2) => x0.slice(x1,x2),
      TI: (x0,x1) => x0.getRandomValues(x1),
      TJ: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      TK: x0 => x0.send(),
      TL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      TM: x0 => x0.kind,
      TN: x0 => x0.topRight,
      TO: (x0,x1) => { x0.type = x1 },
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: (b, o, l) => new DataView(b, o, l),
      UC: (x0,x1) => x0.exec(x1),
      UD: x0 => x0.left,
      UE: o => {
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
      UF: x0 => x0.button,
      UG: x0 => x0.value,
      UH: (x0,x1) => x0.decode(x1),
      UI: () => globalThis.crypto,
      UJ: (x0,x1) => x0.error(x1),
      UK: x0 => x0.type,
      UL: x0 => globalThis.Wakelock.toggle(x0),
      UM: x0 => x0.mediaDevices,
      UN: x0 => x0.topLeft,
      UO: x0 => x0.length,
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      VC: x0 => x0.length,
      VD: x0 => x0.clientY,
      VE: x0 => x0.language,
      VF: x0 => x0.innerHeight,
      VG: x0 => x0.selectionDirection,
      VH: (x0,x1) => x0.adoptText(x1),
      VI: l => new DataView(new ArrayBuffer(l)),
      VJ: () => globalThis.console,
      VK: x0 => x0.response,
      VL: (x0,x1) => x0.appendChild(x1),
      VM: x0 => x0.facingMode,
      VN: x0 => x0.position,
      VO: x0 => x0.getReader(),
      W: x0 => new Array(x0),
      WB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      WC: (x0,x1) => { x0.lastIndex = x1 },
      WD: x0 => x0.clientX,
      WE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      WF: x0 => x0.innerWidth,
      WG: x0 => x0.selectionStart,
      WH: x0 => x0.first(),
      WI: x0 => x0.naturalHeight,
      WJ: () => new MessageChannel(),
      WK: (x0,x1) => { x0.responseType = x1 },
      WL: x0 => x0.id,
      WM: x0 => x0.mediaDevices,
      WN: x0 => x0.isValid,
      WO: x0 => x0.value,
      X: o => [o],
      XB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      XC: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      XD: x0 => x0.changedTouches,
      XE: () => globalThis.window.FinalizationRegistry,
      XF: x0 => x0.height,
      XG: x0 => x0.selectionEnd,
      XH: x0 => x0.next(),
      XI: x0 => x0.naturalWidth,
      XJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XK: x0 => x0.vendor,
      XL: (x0,x1) => x0.createElement(x1),
      XM: () => globalThis.BarcodeDetector.getSupportedFormats(),
      XN: (x0,x1,x2,x3) => ({formats: x0,tryHarder: x1,tryRotate: x2,tryInvert: x3}),
      XO: x0 => x0.done,
      Y: (o0, o1) => [o0, o1],
      YB: (t, s) => t.set(s),
      YC: o => o instanceof RegExp,
      YD: x0 => x0.offsetY,
      YE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      YF: x0 => x0.width,
      YG: x0 => x0.value,
      YH: x0 => x0.current(),
      YI: (x0,x1) => x0.createElement(x1),
      YJ: x0 => x0.port2,
      YK: x0 => x0.navigator,
      YL: (x0,x1) => { x0.id = x1 },
      YM: (x0,x1) => x0.call(x1),
      YN: (x0,x1,x2) => ({tryHarder: x0,tryRotate: x1,tryInvert: x2}),
      YO: x0 => x0.read(),
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      ZC: (string, times) => string.repeat(times),
      ZD: x0 => x0.offsetX,
      ZE: x0 => new window.FinalizationRegistry(x0),
      ZF: x0 => x0.clientHeight,
      ZG: x0 => x0.selectionDirection,
      ZH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      ZI: (x0,x1) => { x0.pointerEvents = x1 },
      ZJ: (x0,x1) => { x0.onmessage = x1 },
      ZK: () => globalThis.window,
      ZL: (x0,x1) => { x0.src = x1 },
      ZM: x0 => x0.reset,
      ZN: () => globalThis.ZXingWASM,
      ZO: x0 => x0.body,
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      aC: x0 => x0.dotAll,
      aD: x0 => x0.type,
      aE: (x0,x1) => x0.unregister(x1),
      aF: x0 => x0.clientWidth,
      aG: x0 => x0.selectionStart,
      aH: x0 => x0.v8BreakIterator,
      aI: (x0,x1) => { x0.height = x1 },
      aJ: x0 => globalThis.Object.keys(x0),
      aK: () => new Array(),
      aL: (x0,x1) => { x0.async = x1 },
      aM: x0 => x0.stopContinuousDecode,
      aN: (x0,x1) => { x0.height = x1 },
      aO: (x0,x1) => new OffscreenCanvas(x0,x1),
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      bC: x0 => x0.unicode,
      bD: x0 => x0.maxTouchPoints,
      bE: (x0,x1) => x0.contains(x1),
      bF: (x0,x1) => { x0.content = x1 },
      bG: x0 => x0.selectionEnd,
      bH: () => globalThis.Intl,
      bI: (x0,x1) => { x0.width = x1 },
      bJ: x0 => x0.length,
      bK: (x0,x1) => new WebSocket(x0,x1),
      bL: (x0,x1) => { x0.charset = x1 },
      bM: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      bN: (x0,x1) => { x0.width = x1 },
      bO: x0 => x0.assetBase,
      c: o => o,
      cB: Function.prototype.call.bind(DataView.prototype.getUint32),
      cC: x0 => x0.ignoreCase,
      cD: x0 => x0.platform,
      cE: (s) => +s,
      cF: (x0,x1) => { x0.name = x1 },
      cG: x0 => x0.keyCode,
      cH: (x0,x1) => x0.segment(x1),
      cI: x0 => x0.style,
      cJ: (o, t) => typeof o === t,
      cK: x0 => x0.reason,
      cL: (x0,x1) => { x0.type = x1 },
      cM: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      cN: x0 => x0.height,
      cO: x0 => x0.loader,
      d: (o, p) => o[p],
      dB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      dC: x0 => x0.multiline,
      dD: x0 => x0.body,
      dE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      dF: x0 => x0.head,
      dG: (x0,x1) => x0.scrollIntoView(x1),
      dH: x0 => x0.index,
      dI: (x0,x1) => { x0.src = x1 },
      dJ: x0 => x0.data,
      dK: x0 => x0.code,
      dL: (x0,x1) => x0.querySelector(x1),
      dM: x0 => x0.text,
      dN: x0 => x0.width,
      dO: () => globalThis._flutter,
      e: () => globalThis,
      eB: Function.prototype.call.bind(DataView.prototype.getInt32),
      eC: (string, token) => string.split(token),
      eD: () => globalThis.document,
      eE: s => s.trim(),
      eF: (x0,x1) => x0.removeChild(x1),
      eG: x0 => x0.multiViewEnabled,
      eH: x0 => x0.next(),
      eI: () => globalThis.document,
      eJ: x0 => x0.port1,
      eK: (x0,x1,x2) => x0.close(x1,x2),
      eL: x0 => x0.head,
      eM: x0 => x0.barcodeFormat,
      eN: (x0,x1) => { x0.srcObject = x1 },
      f: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      fC: o => o instanceof Array,
      fD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      fE: x0 => x0.classList,
      fF: x0 => x0.firstChild,
      fG: (x0,x1) => x0.replaceWith(x1),
      fH: x0 => x0.value,
      fI: x0 => x0.src,
      fJ: (x0,x1) => new SharedWorker(x0,x1),
      fK: (x0,x1) => x0.close(x1),
      fL: () => globalThis.document,
      fM: x0 => x0.rawBytes,
      fN: x0 => ({willReadFrequently: x0}),
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: o => o instanceof Uint16Array,
      gC: (a, i) => a[i],
      gD: x0 => x0.hasFocus(),
      gE: x0 => x0.preventDefault(),
      gF: x0 => x0.viewConstraints,
      gG: (x0,x1) => { x0.type = x1 },
      gH: x0 => x0.done,
      gI: (x0,x1) => x0.revokeObjectURL(x1),
      gJ: x0 => new Worker(x0),
      gK: x0 => x0.close(),
      gL: x0 => x0.userAgent,
      gM: x0 => x0.y,
      gN: (x0,x1,x2) => x0.getContext(x1,x2),
      h: (x0,x1) => ({addView: x0,removeView: x1}),
      hB: Function.prototype.call.bind(DataView.prototype.getUint16),
      hC: a => a.length,
      hD: x0 => x0.relatedTarget,
      hE: x0 => x0.parent,
      hF: x0 => x0.hostElement,
      hG: (x0,x1) => { x0.className = x1 },
      hH: (o, m, a) => o[m].apply(o, a),
      hI: (x0,x1) => { x0.src = x1 },
      hJ: (x0,x1,x2) => x0.postMessage(x1,x2),
      hK: (x0,x1) => x0.send(x1),
      hL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      hM: x0 => x0.x,
      hN: () => new BarcodeDetector(),
      i: (l, r) => l === r,
      iB: o => o instanceof Int16Array,
      iC: (x0,x1) => x0.test(x1),
      iD: x0 => x0.shiftKey,
      iE: x0 => x0.timeStamp,
      iF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iG: (x0,x1) => { x0.tabIndex = x1 },
      iH: x0 => x0.iterator,
      iI: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      iJ: (o, p, v) => o[p] = v,
      iK: x0 => x0.readyState,
      iL: (x0,x1) => x0.key(x1),
      iM: x0 => x0.resultPoints,
      iN: x0 => ({formats: x0}),
      j: x0 => x0.random(),
      jB: Function.prototype.call.bind(DataView.prototype.getInt16),
      jC: x0 => x0.userAgent,
      jD: (decoder, codeUnits) => decoder.decode(codeUnits),
      jE: (x0,x1) => x0.hasAttribute(x1),
      jF: x0 => ({runApp: x0}),
      jG: (x0,x1) => { x0.name = x1 },
      jH: () => globalThis.Symbol,
      jI: x0 => x0.naturalHeight,
      jJ: (x0,x1) => { x0.onerror = x1 },
      jK: (x0,x1) => { x0.binaryType = x1 },
      jL: x0 => x0.length,
      jM: x0 => x0.message,
      jN: x0 => new BarcodeDetector(x0),
      k: o => o,
      kB: o => o instanceof Uint8ClampedArray,
      kC: x0 => x0.navigator,
      kD: () => new TextDecoder("utf-8", {fatal: true}),
      kE: x0 => x0.buttons,
      kF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      kG: (x0,x1) => { x0.placeholder = x1 },
      kH: (x0,x1) => new Intl.Segmenter(x0,x1),
      kI: x0 => x0.naturalWidth,
      kJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      kK: (a, l) => a.length = l,
      kL: (x0,x1) => { x0.transform = x1 },
      kM: x0 => x0.videoElement,
      kN: (x0,x1) => x0.detect(x1),
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
      lD: () => new TextDecoder("utf-8", {fatal: false}),
      lE: x0 => x0.ctrlKey,
      lF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      lG: (x0,x1) => { x0.autocomplete = x1 },
      lH: x0 => x0.Segmenter,
      lI: x0 => x0.decode(),
      lJ: (x0,x1,x2) => x0.postMessage(x1,x2),
      lK: (x0,x1) => x0.getItem(x1),
      lL: x0 => x0.style,
      lM: x0 => x0.decodeContinuously,
      lN: x0 => x0.rawValue,
      m: () => globalThis.Math,
      mB: Function.prototype.call.bind(DataView.prototype.setInt32),
      mC: Object.is,
      mD: (a, i, v) => a[i] = v,
      mE: x0 => x0.y,
      mF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      mG: (x0,x1) => { x0.name = x1 },
      mH: x0 => x0.buffer,
      mI: (x0,x1) => { x0.decoding = x1 },
      mJ: x0 => x0.port,
      mK: x0 => x0.localStorage,
      mL: x0 => x0.getVideoTracks(),
      mM: (x0,x1) => new ZXing.BrowserMultiFormatReader(x0,x1),
      mN: x0 => x0.format,
      n: (x0,x1) => x0.prepend(x1),
      nB: Function.prototype.call.bind(DataView.prototype.setUint32),
      nC: x0 => x0.vendor,
      nD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      nE: x0 => x0.x,
      nF: o => o.byteLength,
      nG: (x0,x1) => { x0.placeholder = x1 },
      nH: x0 => x0.wasmMemory,
      nI: (x0,x1) => { x0.crossOrigin = x1 },
      nJ: (x0,x1) => { x0.onerror = x1 },
      nK: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      nL: x0 => x0.getSettings(),
      nM: (x0,x1) => ({width: x0,height: x1}),
      nN: x0 => x0.y,
      o: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      oB: Function.prototype.call.bind(DataView.prototype.setInt16),
      oC: (x0,x1) => x0.createTextNode(x1),
      oD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      oE: x0 => x0.scrollTop,
      oF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      oG: (x0,x1) => { x0.action = x1 },
      oH: () => globalThis.window._flutter_skwasmInstance,
      oI: (x0,x1) => x0.createObjectURL(x1),
      oJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      oK: x0 => x0.history,
      oL: x0 => x0.facingMode,
      oM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      oN: x0 => x0.x,
      p: b => !!b,
      pB: Function.prototype.call.bind(DataView.prototype.setUint16),
      pC: (x0,x1) => { x0.id = x1 },
      pD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      pE: x0 => x0.offsetTop,
      pF: x0 => x0.history,
      pG: (x0,x1) => { x0.method = x1 },
      pH: () => new TextDecoder(),
      pI: x0 => x0.URL,
      pJ: x0 => x0.abort(),
      pK: x0 => x0.href,
      pL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      pM: x0 => x0.facingMode,
      pN: x0 => x0.cornerPoints,
      q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qB: Function.prototype.call.bind(DataView.prototype.setUint8),
      qC: (x0,x1) => { x0.nonce = x1 },
      qD: x0 => x0.visibilityState,
      qE: x0 => x0.scrollLeft,
      qF: x0 => x0.search,
      qG: (x0,x1) => { x0.noValidate = x1 },
      qH: x0 => x0.debugSkipFontRetryDelay,
      qI: x0 => new Blob(x0),
      qJ: () => new AbortController(),
      qK: x0 => x0.location,
      qL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qM: x0 => x0.height,
      qN: x0 => x0.body,
      r: (x0,x1) => x0.focus(x1),
      rB: Function.prototype.call.bind(DataView.prototype.setInt8),
      rC: x0 => x0.nonce,
      rD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      rE: x0 => x0.offsetLeft,
      rF: x0 => x0.location,
      rG: (x0,x1) => x0.removeAttribute(x1),
      rH: (x0,x1,x2) => x0.set(x1,x2),
      rI: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      rJ: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      rK: (x0,x1) => x0.removeItem(x1),
      rL: (x0,x1) => x0.append(x1),
      rM: x0 => x0.width,
      rN: x0 => globalThis.URL.revokeObjectURL(x0),
      s: () => ({}),
      sB: Function.prototype.call.bind(DataView.prototype.getInt8),
      sC: () => globalThis.window.flutterConfiguration,
      sD: x0 => x0.disconnect(),
      sE: x0 => x0.offsetParent,
      sF: x0 => x0.pathname,
      sG: x0 => x0.isConnected,
      sH: x0 => x0.fontFallbackBaseUrl,
      sI: x0 => new window.ImageDecoder(x0),
      sJ: (x0,x1) => globalThis.fetch(x0,x1),
      sK: (x0,x1,x2) => x0.setItem(x1,x2),
      sL: (x0,x1) => { x0.onpause = x1 },
      sM: x0 => x0.attachStreamToVideo,
      sN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      t: (o, p, v) => o[p] = v,
      tB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      tC: (x0,x1) => x0.attachShadow(x1),
      tD: x0 => new Intl.Locale(x0),
      tE: (o, p, r) => o.replace(p, () => r),
      tF: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      tG: x0 => x0.click(),
      tH: (handle) => clearInterval(handle),
      tI: x0 => x0.name,
      tJ: (x0,x1) => x0.get(x1),
      tK: x0 => new BroadcastChannel(x0),
      tL: (x0,x1) => { x0.onplay = x1 },
      tM: () => new Map(),
      tN: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      u: () => [],
      uB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      uC: (x0,x1) => x0.createElement(x1),
      uD: x0 => x0.region,
      uE: (o, p, r) => o.replaceAll(p, () => r),
      uF: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      uG: (x0,x1) => x0.getElementsByClassName(x1),
      uH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      uI: x0 => x0.repetitionCount,
      uJ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      uK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uL: (x0,x1) => { x0.controls = x1 },
      uM: (x0,x1,x2) => x0.set(x1,x2),
      uN: x0 => globalThis.URL.createObjectURL(x0),
      v: (a, i) => a.push(i),
      vB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      vC: x0 => x0.scale,
      vD: x0 => x0.script,
      vE: x0 => x0.deltaMode,
      vF: o => Object.keys(o),
      vG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      vH: () => Date.now(),
      vI: x0 => x0.frameCount,
      vJ: (x0,x1) => x0.forEach(x1),
      vK: x0 => x0.close(),
      vL: (x0,x1) => { x0.pointerEvents = x1 },
      vM: (x0,x1) => x0.querySelector(x1),
      vN: x0 => x0.size,
      w: x0 => new Int8Array(x0),
      wB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      wC: x0 => x0.visualViewport,
      wD: x0 => x0.language,
      wE: x0 => x0.deltaY,
      wF: x0 => x0.state,
      wG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      wH: (x0,x1,x2) => x0.insertBefore(x1,x2),
      wI: x0 => x0.selectedTrack,
      wJ: x0 => x0.name,
      wK: (x0,x1) => x0.postMessage(x1),
      wL: (x0,x1) => { x0.transformOrigin = x1 },
      wM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wN: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),
      x: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      xC: x0 => x0.devicePixelRatio,
      xD: x0 => x0.languages,
      xE: x0 => x0.deltaX,
      xF: x0 => x0.hash,
      xG: (x0,x1) => x0.dispatchEvent(x1),
      xH: x0 => x0.id,
      xI: x0 => x0.completed,
      xJ: x0 => x0.statusText,
      xK: (x0,x1) => { x0.onmessage = x1 },
      xL: (x0,x1) => { x0.objectFit = x1 },
      xM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      xN: (x0,x1) => x0.getContext(x1),
      y: x0 => new Uint8Array(x0),
      yB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      yC: x0 => x0.height,
      yD: (x0,x1) => x0.observe(x1),
      yE: x0 => x0.wheelDeltaY,
      yF: x0 => x0.state,
      yG: (x0,x1) => x0.createEvent(x1),
      yH: x0 => x0.offsetHeight,
      yI: x0 => x0.ready,
      yJ: x0 => x0.url,
      yK: (x0,x1) => x0.transferFromImageBitmap(x1),
      yL: (x0,x1) => { x0.width = x1 },
      yM: (x0,x1) => { x0.onerror = x1 },
      yN: x0 => x0.height,
      z: x0 => new Uint8ClampedArray(x0),
      zB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      zC: x0 => x0.width,
      zD: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      zE: x0 => x0.wheelDeltaX,
      zF: (x0,x1) => x0.go(x1),
      zG: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      zH: x0 => x0.offsetWidth,
      zI: x0 => x0.tracks,
      zJ: x0 => x0.status,
      zK: (x0,x1) => x0.getContext(x1),
      zL: (x0,x1) => { x0.height = x1 },
      zM: (x0,x1) => x0.removeChild(x1),
      zN: x0 => x0.width,

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
