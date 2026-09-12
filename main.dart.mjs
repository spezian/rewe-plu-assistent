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
      AC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      AD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      AE: x0 => globalThis.parseFloat(x0),
      AF: x0 => x0.touches,
      AG: (x0,x1) => x0.requestAnimationFrame(x1),
      AH: (x0,x1) => x0.writeText(x1),
      AI: (x0,x1) => { x0.min = x1 },
      AJ: x0 => x0.displayHeight,
      AK: x0 => x0.navigator,
      AL: x0 => x0.rasterEndMilliseconds,
      AM: (x0,x1) => ({width: x0,height: x1}),
      AN: x0 => x0.videoHeight,
      AO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      B: s => printToConsole(s),
      BB: x0 => new Uint16Array(x0),
      BC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      BD: x0 => x0.tabIndex,
      BE: (x0,x1) => x0.getComputedStyle(x1),
      BF: x0 => x0.pressure,
      BG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      BH: x0 => x0.unlock(),
      BI: (x0,x1) => { x0.max = x1 },
      BJ: x0 => x0.displayWidth,
      BK: () => globalThis.window,
      BL: x0 => x0.rasterStartMilliseconds,
      BM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      BN: x0 => x0.videoWidth,
      BO: (x0,x1) => { x0.oncancel = x1 },
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: x0 => new Int32Array(x0),
      CC: (x0,x1) => x0.querySelector(x1),
      CD: (x0,x1) => x0.contains(x1),
      CE: x0 => x0.documentElement,
      CF: x0 => x0.tiltY,
      CG: x0 => x0.now(),
      CH: (x0,x1) => x0.lock(x1),
      CI: (x0,x1) => { x0.disabled = x1 },
      CJ: x0 => x0.duration,
      CK: (x0,x1) => x0.error(x1),
      CL: x0 => x0.imageBitmaps,
      CM: (x0,x1) => x0.getUserMedia(x1),
      CN: x0 => x0.stream,
      CO: (x0,x1) => { x0.onchange = x1 },
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      DC: (x0,x1) => x0.item(x1),
      DD: x0 => x0.activeElement,
      DE: x0 => x0.computedStyleMap(),
      DF: x0 => x0.tiltX,
      DG: x0 => x0.performance,
      DH: x0 => x0.orientation,
      DI: (x0,x1) => { x0.scrollLeft = x1 },
      DJ: x0 => x0.image,
      DK: () => globalThis.console,
      DL: x0 => x0.canvasKitMaximumSurfaces,
      DM: x0 => x0.deviceId,
      DN: x0 => x0.play(),
      DO: x0 => x0.type,
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: x0 => new Uint32Array(x0),
      EC: x0 => x0.length,
      ED: x0 => x0.parentNode,
      EE: (x0,x1) => x0.get(x1),
      EF: x0 => x0.pointerType,
      EG: (d, digits) => d.toFixed(digits),
      EH: (x0,x1) => x0.querySelector(x1),
      EI: (x0,x1) => { x0.spellcheck = x1 },
      EJ: () => globalThis.window.ImageDecoder,
      EK: () => new MessageChannel(),
      EL: x0 => x0.nextSibling,
      EM: x0 => x0.getCapabilities(),
      EN: x0 => x0.paused,
      EO: x0 => x0.lastModified,
      F: () => new Error().stack,
      FB: x0 => new Float32Array(x0),
      FC: (x0,x1) => x0.querySelectorAll(x1),
      FD: x0 => x0.tagName,
      FE: (o, p) => p in o,
      FF: x0 => x0.pointerId,
      FG: x0 => x0.maxHeight,
      FH: (x0,x1) => { x0.title = x1 },
      FI: (x0,x1) => { x0.disabled = x1 },
      FJ: x0 => x0.decode(),
      FK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      FL: (x0,x1) => x0.debug(x1),
      FM: () => ({}),
      FN: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      FO: x0 => x0.name,
      G: s => JSON.stringify(s),
      GB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      GC: (x0,x1) => x0.getAttribute(x1),
      GD: x0 => x0.target,
      GE: (x0,x1) => { x0.textContent = x1 },
      GF: x0 => x0.getCoalescedEvents(),
      GG: x0 => x0.maxWidth,
      GH: (x0,x1) => x0.vibrate(x1),
      GI: (a, i) => a.splice(i, 1),
      GJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      GK: x0 => x0.port2,
      GL: x0 => x0.hostElement,
      GM: (x0,x1) => x0.applyConstraints(x1),
      GN: (x0,x1,x2,x3,x4) => x0.getImageData(x1,x2,x3,x4),
      GO: (x0,x1) => x0.item(x1),
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: x0 => new Float64Array(x0),
      HC: x0 => x0.remove(),
      HD: x0 => x0.clientY,
      HE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      HF: (x0,x1) => x0.getModifierState(x1),
      HG: x0 => x0.minHeight,
      HH: x0 => x0.arrayBuffer(),
      HI: a => a.pop(),
      HJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      HK: (x0,x1) => { x0.onmessage = x1 },
      HL: x0 => x0.location,
      HM: (x0,x1) => { x0.whiteBalanceMode = x1 },
      HN: (x0,x1,x2) => x0.readBarcodes(x1,x2),
      HO: x0 => x0.length,
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      IC: (x0,x1) => x0.appendChild(x1),
      ID: x0 => x0.clientX,
      IE: x0 => x0.matches,
      IF: s => s.trimLeft(),
      IG: x0 => x0.minWidth,
      IH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      II: (map, o, v) => map.set(o, v),
      IJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      IK: x0 => globalThis.Object.keys(x0),
      IL: (x0,x1) => x0.getModifierState(x1),
      IM: x0 => x0.whiteBalanceMode,
      IN: x0 => x0.text,
      IO: x0 => x0.files,
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: x0 => new ArrayBuffer(x0),
      JC: (x0,x1) => x0.append(x1),
      JD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      JE: (x0,x1) => x0.matchMedia(x1),
      JF: s => s.toUpperCase(),
      JG: (x0,x1) => x0.removeProperty(x1),
      JH: x0 => x0.status,
      JI: (map, o) => map.get(o),
      JJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JK: x0 => x0.length,
      JL: x0 => x0.metaKey,
      JM: (x0,x1) => { x0.exposureMode = x1 },
      JN: x0 => x0.format,
      JO: x0 => x0.target,
      K: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      KB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      KC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      KD: x0 => x0.getBoundingClientRect(),
      KE: x0 => x0.matches,
      KF: (x0,x1) => x0[x1],
      KG: (x0,x1) => x0.add(x1),
      KH: (x0,x1) => x0.fetch(x1),
      KI: () => new WeakMap(),
      KJ: x0 => x0.send(),
      KK: (o, t) => typeof o === t,
      KL: x0 => x0.altKey,
      KM: x0 => x0.exposureMode,
      KN: x0 => x0.bytes,
      KO: (x0,x1) => x0.replaceChildren(x1),
      L: o => o === undefined,
      LB: (x0,x1,x2) => new DataView(x0,x1,x2),
      LC: x0 => x0.style,
      LD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      LE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      LF: x0 => x0.index,
      LG: x0 => x0.data,
      LH: x0 => x0.content,
      LI: x0 => new WeakRef(x0),
      LJ: x0 => x0.status,
      LK: x0 => x0.data,
      LL: x0 => x0.ctrlKey,
      LM: (x0,x1) => { x0.focusMode = x1 },
      LN: x0 => x0.y,
      LO: x0 => x0.click(),
      M: o => String(o),
      MB: (o, p) => o[p],
      MC: x0 => x0.debugShowSemanticsNodes,
      MD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      ME: f => f.dartFunction,
      MF: x0 => x0.flags,
      MG: (x0,x1) => { x0.scrollTop = x1 },
      MH: x0 => x0.document,
      MI: x0 => x0.deref(),
      MJ: x0 => x0.response,
      MK: x0 => x0.port1,
      ML: x0 => x0.isComposing,
      MM: x0 => x0.focusMode,
      MN: x0 => x0.x,
      MO: (x0,x1,x2) => x0.setAttribute(x1,x2),
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      NC: o => o,
      ND: Date.now,
      NE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NF: (a, s) => a.join(s),
      NG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      NH: () => typeof dartUseDateNowForTicks !== "undefined",
      NI: () => globalThis.WeakRef,
      NJ: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      NK: (x0,x1) => new SharedWorker(x0,x1),
      NL: x0 => x0.code,
      NM: x0 => x0.enumerateDevices(),
      NN: x0 => x0.bottomLeft,
      NO: (x0,x1) => { x0.accept = x1 },
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      OC: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      OD: (handle) => clearTimeout(handle),
      OE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      OF: (x0,x1) => x0.error(x1),
      OG: (x0,x1) => { x0.value = x1 },
      OH: () => Date.now(),
      OI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      OJ: (x0,x1) => { x0.responseType = x1 },
      OK: x0 => new Worker(x0),
      OL: x0 => x0.repeat,
      OM: x0 => x0.deviceId,
      ON: x0 => x0.bottomRight,
      OO: (x0,x1) => { x0.multiple = x1 },
      P: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PB: o => o.byteOffset,
      PC: (x0,x1) => x0.warn(x1),
      PD: (x0,x1) => x0.closest(x1),
      PE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      PF: () => globalThis.console,
      PG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      PH: () => 1000 * performance.now(),
      PI: (a, s, e) => a.slice(s, e),
      PJ: () => new XMLHttpRequest(),
      PK: (x0,x1,x2) => x0.postMessage(x1,x2),
      PL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PM: x0 => x0.kind,
      PN: x0 => x0.topRight,
      PO: (x0,x1) => { x0.type = x1 },
      Q: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      QB: o => o.buffer,
      QC: x0 => x0.console,
      QD: x0 => x0.bottom,
      QE: (o, i) => o[i],
      QF: s => s.trimRight(),
      QG: (x0,x1) => { x0.value = x1 },
      QH: x0 => new Uint8Array(x0),
      QI: (x0,x1) => x0.getRandomValues(x1),
      QJ: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      QK: (o, p, v) => o[p] = v,
      QL: x0 => globalThis.Wakelock.toggle(x0),
      QM: x0 => x0.mediaDevices,
      QN: x0 => x0.topLeft,
      QO: x0 => x0.length,
      R: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      RB: Function.prototype.call.bind(DataView.prototype.getUint8),
      RC: () => globalThis.window,
      RD: x0 => x0.top,
      RE: o => o.length,
      RF: x0 => x0.blur(),
      RG: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      RH: (x0,x1,x2) => x0.slice(x1,x2),
      RI: () => globalThis.crypto,
      RJ: x0 => x0.abort(),
      RK: (x0,x1) => { x0.onerror = x1 },
      RL: (x0,x1) => x0.appendChild(x1),
      RM: x0 => x0.facingMode,
      RN: x0 => x0.position,
      RO: x0 => x0.getReader(),
      S: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SB: (b, o) => new DataView(b, o),
      SC: (o, c) => o instanceof c,
      SD: x0 => x0.right,
      SE: o => {
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
      SF: x0 => x0.button,
      SG: x0 => x0.value,
      SH: (x0,x1) => x0.decode(x1),
      SI: l => new DataView(new ArrayBuffer(l)),
      SJ: () => new AbortController(),
      SK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      SL: x0 => x0.id,
      SM: x0 => x0.mediaDevices,
      SN: x0 => x0.isValid,
      SO: x0 => x0.value,
      T: x0 => new Promise(x0),
      TB: (b, o, l) => new DataView(b, o, l),
      TC: (x0,x1) => x0.exec(x1),
      TD: x0 => x0.left,
      TE: x0 => x0.language,
      TF: x0 => x0.innerHeight,
      TG: x0 => x0.selectionDirection,
      TH: (x0,x1) => x0.adoptText(x1),
      TI: x0 => x0.naturalHeight,
      TJ: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      TK: (x0,x1,x2) => x0.postMessage(x1,x2),
      TL: (x0,x1) => x0.createElement(x1),
      TM: () => globalThis.BarcodeDetector.getSupportedFormats(),
      TN: (x0,x1,x2,x3) => ({formats: x0,tryHarder: x1,tryRotate: x2,tryInvert: x3}),
      TO: x0 => x0.done,
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      UC: x0 => x0.length,
      UD: x0 => x0.clientY,
      UE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      UF: x0 => x0.innerWidth,
      UG: x0 => x0.selectionStart,
      UH: x0 => x0.first(),
      UI: x0 => x0.naturalWidth,
      UJ: (x0,x1) => globalThis.fetch(x0,x1),
      UK: x0 => x0.port,
      UL: (x0,x1) => { x0.id = x1 },
      UM: (x0,x1) => x0.call(x1),
      UN: (x0,x1,x2) => ({tryHarder: x0,tryRotate: x1,tryInvert: x2}),
      UO: x0 => x0.read(),
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      VC: (x0,x1) => { x0.lastIndex = x1 },
      VD: x0 => x0.clientX,
      VE: () => globalThis.window.FinalizationRegistry,
      VF: x0 => x0.height,
      VG: x0 => x0.selectionEnd,
      VH: x0 => x0.next(),
      VI: (x0,x1) => x0.createElement(x1),
      VJ: (x0,x1) => x0.get(x1),
      VK: (x0,x1) => { x0.onerror = x1 },
      VL: (x0,x1) => { x0.src = x1 },
      VM: x0 => x0.reset,
      VN: () => globalThis.ZXingWASM,
      VO: x0 => x0.body,
      W: x0 => new Array(x0),
      WB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      WC: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      WD: x0 => x0.changedTouches,
      WE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WF: x0 => x0.width,
      WG: x0 => x0.value,
      WH: x0 => x0.current(),
      WI: (x0,x1) => { x0.pointerEvents = x1 },
      WJ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      WK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WL: (x0,x1) => { x0.async = x1 },
      WM: x0 => x0.stopContinuousDecode,
      WN: (x0,x1) => { x0.height = x1 },
      WO: (x0,x1) => new OffscreenCanvas(x0,x1),
      X: o => [o],
      XB: (t, s) => t.set(s),
      XC: o => o instanceof RegExp,
      XD: x0 => x0.offsetY,
      XE: x0 => new window.FinalizationRegistry(x0),
      XF: x0 => x0.clientHeight,
      XG: x0 => x0.selectionDirection,
      XH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      XI: (x0,x1) => { x0.height = x1 },
      XJ: (x0,x1) => x0.forEach(x1),
      XK: (x0,x1) => x0.getItem(x1),
      XL: (x0,x1) => { x0.charset = x1 },
      XM: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      XN: (x0,x1) => { x0.width = x1 },
      XO: x0 => x0.assetBase,
      Y: (o0, o1) => [o0, o1],
      YB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      YC: (string, times) => string.repeat(times),
      YD: x0 => x0.offsetX,
      YE: (x0,x1) => x0.unregister(x1),
      YF: x0 => x0.clientWidth,
      YG: x0 => x0.selectionStart,
      YH: x0 => x0.v8BreakIterator,
      YI: (x0,x1) => { x0.width = x1 },
      YJ: x0 => x0.name,
      YK: x0 => x0.localStorage,
      YL: (x0,x1) => { x0.type = x1 },
      YM: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      YN: x0 => x0.height,
      YO: x0 => x0.loader,
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      ZC: x0 => x0.dotAll,
      ZD: x0 => x0.type,
      ZE: (x0,x1) => x0.contains(x1),
      ZF: (x0,x1) => { x0.content = x1 },
      ZG: x0 => x0.selectionEnd,
      ZH: () => globalThis.Intl,
      ZI: x0 => x0.style,
      ZJ: x0 => x0.statusText,
      ZK: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      ZL: (x0,x1) => x0.querySelector(x1),
      ZM: x0 => x0.text,
      ZN: x0 => x0.width,
      ZO: () => globalThis._flutter,
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      aC: x0 => x0.unicode,
      aD: x0 => x0.maxTouchPoints,
      aE: (s) => +s,
      aF: (x0,x1) => { x0.name = x1 },
      aG: x0 => x0.keyCode,
      aH: (x0,x1) => x0.segment(x1),
      aI: (x0,x1) => { x0.src = x1 },
      aJ: x0 => x0.url,
      aK: x0 => x0.history,
      aL: x0 => x0.head,
      aM: x0 => x0.barcodeFormat,
      aN: (x0,x1) => { x0.srcObject = x1 },
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: Function.prototype.call.bind(DataView.prototype.getUint32),
      bC: x0 => x0.ignoreCase,
      bD: x0 => x0.platform,
      bE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      bF: x0 => x0.head,
      bG: (x0,x1) => x0.scrollIntoView(x1),
      bH: x0 => x0.index,
      bI: () => globalThis.document,
      bJ: x0 => x0.status,
      bK: x0 => x0.href,
      bL: () => globalThis.document,
      bM: x0 => x0.rawBytes,
      bN: x0 => ({willReadFrequently: x0}),
      c: o => o,
      cB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      cC: x0 => x0.multiline,
      cD: x0 => x0.body,
      cE: s => s.trim(),
      cF: (x0,x1) => x0.removeChild(x1),
      cG: x0 => x0.multiViewEnabled,
      cH: x0 => x0.next(),
      cI: x0 => x0.src,
      cJ: x0 => x0.getReader(),
      cK: x0 => x0.location,
      cL: x0 => x0.userAgent,
      cM: x0 => x0.y,
      cN: (x0,x1,x2) => x0.getContext(x1,x2),
      d: (o, p) => o[p],
      dB: Function.prototype.call.bind(DataView.prototype.getInt32),
      dC: (string, token) => string.split(token),
      dD: () => globalThis.document,
      dE: x0 => x0.classList,
      dF: x0 => x0.firstChild,
      dG: (x0,x1) => x0.replaceWith(x1),
      dH: x0 => x0.value,
      dI: (x0,x1) => x0.revokeObjectURL(x1),
      dJ: x0 => x0.read(),
      dK: (x0,x1) => x0.removeItem(x1),
      dL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      dM: x0 => x0.x,
      dN: () => new BarcodeDetector(),
      e: () => globalThis,
      eB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      eC: o => o instanceof Array,
      eD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      eE: x0 => x0.preventDefault(),
      eF: x0 => x0.viewConstraints,
      eG: (x0,x1) => { x0.type = x1 },
      eH: x0 => x0.done,
      eI: (x0,x1) => { x0.src = x1 },
      eJ: x0 => x0.value,
      eK: (x0,x1,x2) => x0.setItem(x1,x2),
      eL: (x0,x1) => x0.key(x1),
      eM: x0 => x0.resultPoints,
      eN: x0 => ({formats: x0}),
      f: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fB: o => o instanceof Uint16Array,
      fC: (a, i) => a[i],
      fD: x0 => x0.hasFocus(),
      fE: x0 => x0.parent,
      fF: x0 => x0.hostElement,
      fG: (x0,x1) => { x0.className = x1 },
      fH: (o, m, a) => o[m].apply(o, a),
      fI: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      fJ: x0 => x0.done,
      fK: () => new Array(),
      fL: x0 => x0.length,
      fM: x0 => x0.message,
      fN: x0 => new BarcodeDetector(x0),
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: Function.prototype.call.bind(DataView.prototype.getUint16),
      gC: a => a.length,
      gD: x0 => x0.relatedTarget,
      gE: x0 => x0.timeStamp,
      gF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gG: (x0,x1) => { x0.tabIndex = x1 },
      gH: x0 => x0.iterator,
      gI: x0 => x0.naturalHeight,
      gJ: x0 => x0.cancel(),
      gK: (x0,x1) => new WebSocket(x0,x1),
      gL: (x0,x1) => { x0.transform = x1 },
      gM: x0 => x0.videoElement,
      gN: (x0,x1) => x0.detect(x1),
      h: (x0,x1) => ({addView: x0,removeView: x1}),
      hB: o => o instanceof Int16Array,
      hC: (x0,x1) => x0.test(x1),
      hD: x0 => x0.shiftKey,
      hE: (x0,x1) => x0.hasAttribute(x1),
      hF: x0 => ({runApp: x0}),
      hG: (x0,x1) => { x0.name = x1 },
      hH: () => globalThis.Symbol,
      hI: x0 => x0.naturalWidth,
      hJ: x0 => x0.body,
      hK: x0 => x0.reason,
      hL: x0 => x0.style,
      hM: x0 => x0.decodeContinuously,
      hN: x0 => x0.rawValue,
      i: (l, r) => l === r,
      iB: Function.prototype.call.bind(DataView.prototype.getInt16),
      iC: x0 => x0.userAgent,
      iD: (decoder, codeUnits) => decoder.decode(codeUnits),
      iE: x0 => x0.buttons,
      iF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      iG: (x0,x1) => { x0.placeholder = x1 },
      iH: (x0,x1) => new Intl.Segmenter(x0,x1),
      iI: x0 => x0.decode(),
      iJ: x0 => x0.headers,
      iK: x0 => x0.code,
      iL: x0 => x0.getVideoTracks(),
      iM: (x0,x1) => new ZXing.BrowserMultiFormatReader(x0,x1),
      iN: x0 => x0.format,
      j: x0 => x0.random(),
      jB: o => o instanceof Uint8ClampedArray,
      jC: x0 => x0.navigator,
      jD: () => new TextDecoder("utf-8", {fatal: true}),
      jE: x0 => x0.ctrlKey,
      jF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      jG: (x0,x1) => { x0.autocomplete = x1 },
      jH: x0 => x0.Segmenter,
      jI: (x0,x1) => { x0.decoding = x1 },
      jJ: x0 => x0.signal,
      jK: (x0,x1,x2) => x0.close(x1,x2),
      jL: x0 => x0.getSettings(),
      jM: (x0,x1) => ({width: x0,height: x1}),
      jN: x0 => x0.y,
      k: o => o,
      kB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      kC: Function.prototype.call.bind(String.prototype.toLowerCase),
      kD: () => new TextDecoder("utf-8", {fatal: false}),
      kE: x0 => x0.y,
      kF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      kG: (x0,x1) => { x0.name = x1 },
      kH: x0 => x0.buffer,
      kI: (x0,x1) => { x0.crossOrigin = x1 },
      kJ: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      kK: (x0,x1) => x0.close(x1),
      kL: x0 => x0.facingMode,
      kM: (x0,x1,x2) => ({width: x0,height: x1,facingMode: x2}),
      kN: x0 => x0.x,
      l: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      lB: Function.prototype.call.bind(DataView.prototype.setInt32),
      lC: Object.is,
      lD: (a, i, v) => a[i] = v,
      lE: x0 => x0.x,
      lF: o => o.byteLength,
      lG: (x0,x1) => { x0.placeholder = x1 },
      lH: x0 => x0.wasmMemory,
      lI: (x0,x1) => x0.createObjectURL(x1),
      lJ: x0 => x0.pop(),
      lK: x0 => x0.close(),
      lL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      lM: x0 => x0.facingMode,
      lN: x0 => x0.cornerPoints,
      m: () => globalThis.Math,
      mB: Function.prototype.call.bind(DataView.prototype.setUint32),
      mC: x0 => x0.vendor,
      mD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      mE: x0 => x0.scrollTop,
      mF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      mG: (x0,x1) => { x0.action = x1 },
      mH: () => globalThis.window._flutter_skwasmInstance,
      mI: x0 => x0.URL,
      mJ: () => new FileReader(),
      mK: (x0,x1) => x0.send(x1),
      mL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      mM: x0 => x0.height,
      mN: x0 => x0.body,
      n: (x0,x1) => x0.prepend(x1),
      nB: Function.prototype.call.bind(DataView.prototype.setInt16),
      nC: (x0,x1) => x0.createTextNode(x1),
      nD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      nE: x0 => x0.offsetTop,
      nF: x0 => x0.history,
      nG: (x0,x1) => { x0.method = x1 },
      nH: () => new TextDecoder(),
      nI: x0 => new Blob(x0),
      nJ: (x0,x1) => x0.readAsArrayBuffer(x1),
      nK: x0 => x0.readyState,
      nL: (x0,x1) => x0.append(x1),
      nM: x0 => x0.width,
      nN: x0 => globalThis.URL.revokeObjectURL(x0),
      o: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      oB: Function.prototype.call.bind(DataView.prototype.setUint16),
      oC: (x0,x1) => { x0.id = x1 },
      oD: x0 => x0.visibilityState,
      oE: x0 => x0.scrollLeft,
      oF: x0 => x0.search,
      oG: (x0,x1) => { x0.noValidate = x1 },
      oH: x0 => x0.debugSkipFontRetryDelay,
      oI: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      oJ: x0 => x0.result,
      oK: (x0,x1) => { x0.binaryType = x1 },
      oL: (x0,x1) => { x0.onpause = x1 },
      oM: x0 => x0.attachStreamToVideo,
      oN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      p: b => !!b,
      pB: Function.prototype.call.bind(DataView.prototype.setUint8),
      pC: (x0,x1) => { x0.nonce = x1 },
      pD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      pE: x0 => x0.offsetLeft,
      pF: x0 => x0.location,
      pG: (x0,x1) => x0.removeAttribute(x1),
      pH: (x0,x1,x2) => x0.set(x1,x2),
      pI: x0 => new window.ImageDecoder(x0),
      pJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      pK: x0 => new BroadcastChannel(x0),
      pL: (x0,x1) => { x0.onplay = x1 },
      pM: () => new Map(),
      pN: (x0,x1,x2,x3) => x0.toBlob(x1,x2,x3),
      q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qB: Function.prototype.call.bind(DataView.prototype.setInt8),
      qC: x0 => x0.nonce,
      qD: x0 => x0.disconnect(),
      qE: x0 => x0.offsetParent,
      qF: x0 => x0.pathname,
      qG: x0 => x0.isConnected,
      qH: x0 => x0.fontFallbackBaseUrl,
      qI: x0 => x0.name,
      qJ: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      qK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qL: (x0,x1) => { x0.controls = x1 },
      qM: (x0,x1,x2) => x0.set(x1,x2),
      qN: x0 => globalThis.URL.createObjectURL(x0),
      r: (x0,x1) => x0.focus(x1),
      rB: Function.prototype.call.bind(DataView.prototype.getInt8),
      rC: () => globalThis.window.flutterConfiguration,
      rD: x0 => new Intl.Locale(x0),
      rE: (o, p, r) => o.replace(p, () => r),
      rF: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      rG: x0 => x0.click(),
      rH: (handle) => clearInterval(handle),
      rI: x0 => x0.repetitionCount,
      rJ: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      rK: x0 => x0.close(),
      rL: (x0,x1) => { x0.pointerEvents = x1 },
      rM: (x0,x1) => x0.querySelector(x1),
      rN: x0 => x0.size,
      s: () => ({}),
      sB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      sC: (x0,x1) => x0.attachShadow(x1),
      sD: x0 => x0.region,
      sE: (o, p, r) => o.replaceAll(p, () => r),
      sF: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      sG: (x0,x1) => x0.getElementsByClassName(x1),
      sH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      sI: x0 => x0.frameCount,
      sJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sK: (x0,x1) => x0.postMessage(x1),
      sL: (x0,x1) => { x0.transformOrigin = x1 },
      sM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sN: (x0,x1,x2,x3,x4,x5) => x0.drawImage(x1,x2,x3,x4,x5),
      t: (o, p, v) => o[p] = v,
      tB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      tC: (x0,x1) => x0.createElement(x1),
      tD: x0 => x0.script,
      tE: x0 => x0.deltaMode,
      tF: o => Object.keys(o),
      tG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      tH: () => Date.now(),
      tI: x0 => x0.selectedTrack,
      tJ: () => new XMLHttpRequest(),
      tK: (x0,x1) => { x0.onmessage = x1 },
      tL: (x0,x1) => { x0.objectFit = x1 },
      tM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tN: (x0,x1) => x0.getContext(x1),
      u: () => [],
      uB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      uC: x0 => x0.scale,
      uD: x0 => x0.language,
      uE: x0 => x0.deltaY,
      uF: x0 => x0.state,
      uG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      uH: (x0,x1,x2) => x0.insertBefore(x1,x2),
      uI: x0 => x0.completed,
      uJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      uK: (x0,x1) => x0.transferFromImageBitmap(x1),
      uL: (x0,x1) => { x0.width = x1 },
      uM: (x0,x1) => { x0.onerror = x1 },
      uN: x0 => x0.height,
      v: (a, i) => a.push(i),
      vB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      vC: x0 => x0.visualViewport,
      vD: x0 => x0.languages,
      vE: x0 => x0.deltaX,
      vF: x0 => x0.hash,
      vG: (x0,x1) => x0.dispatchEvent(x1),
      vH: x0 => x0.id,
      vI: x0 => x0.ready,
      vJ: x0 => x0.send(),
      vK: (x0,x1) => x0.getContext(x1),
      vL: (x0,x1) => { x0.height = x1 },
      vM: (x0,x1) => x0.removeChild(x1),
      vN: x0 => x0.width,
      w: x0 => new Int8Array(x0),
      wB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      wC: x0 => x0.devicePixelRatio,
      wD: (x0,x1) => x0.observe(x1),
      wE: x0 => x0.wheelDeltaY,
      wF: x0 => x0.state,
      wG: (x0,x1) => x0.createEvent(x1),
      wH: x0 => x0.offsetHeight,
      wI: x0 => x0.tracks,
      wJ: x0 => x0.type,
      wK: (x0,x1) => { x0.height = x1 },
      wL: x0 => x0.getSupportedConstraints(),
      wM: (x0,x1) => { x0.onload = x1 },
      wN: x0 => x0.remove(),
      x: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      xC: x0 => x0.height,
      xD: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      xE: x0 => x0.wheelDeltaX,
      xF: (x0,x1) => x0.go(x1),
      xG: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      xH: x0 => x0.offsetWidth,
      xI: x0 => x0.close(),
      xJ: x0 => x0.response,
      xK: (x0,x1) => { x0.width = x1 },
      xL: x0 => ({ideal: x0}),
      xM: (x0,x1) => { x0.crossOrigin = x1 },
      xN: (x0,x1) => { x0.src = x1 },
      y: x0 => new Uint8Array(x0),
      yB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      yC: x0 => x0.width,
      yD: x0 => new ResizeObserver(x0),
      yE: x0 => x0.key,
      yF: x0 => x0.parentElement,
      yG: x0 => x0.readText(),
      yH: x0 => x0.stopPropagation(),
      yI: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      yJ: (x0,x1) => { x0.responseType = x1 },
      yK: x0 => x0.height,
      yL: (x0,x1,x2) => ({width: x0,height: x1,deviceId: x2}),
      yM: (x0,x1) => { x0.lang = x1 },
      yN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      z: x0 => new Uint8ClampedArray(x0),
      zB: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      zC: x0 => x0.screen,
      zD: (x0,x1) => x0.getPropertyValue(x1),
      zE: x0 => x0.identifier,
      zF: (x0,x1) => x0.querySelectorAll(x1),
      zG: x0 => x0.clipboard,
      zH: x0 => x0.disabled,
      zI: (x0,x1) => x0.decode(x1),
      zJ: x0 => x0.vendor,
      zK: x0 => x0.width,
      zL: x0 => ({video: x0}),
      zM: (x0,x1) => { x0.defer = x1 },
      zN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),

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
