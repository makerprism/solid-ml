// node_modules/melange.js/caml.js
function caml_int_min(x, y) {
  if (x < y) {
    return x;
  } else {
    return y;
  }
}
function caml_int_max(x, y) {
  if (x > y) {
    return x;
  } else {
    return y;
  }
}
function i64_eq(x, y) {
  if (x[1] === y[1]) {
    return x[0] === y[0];
  } else {
    return false;
  }
}
function i64_ge(param, param$1) {
  const other_hi = param$1[0];
  const hi = param[0];
  if (hi > other_hi) {
    return true;
  } else if (hi < other_hi) {
    return false;
  } else {
    return param[1] >= param$1[1];
  }
}
function i64_neq(x, y) {
  return !i64_eq(x, y);
}
function i64_lt(x, y) {
  return !i64_ge(x, y);
}
function i64_gt(x, y) {
  if (x[0] > y[0]) {
    return true;
  } else if (x[0] < y[0]) {
    return false;
  } else {
    return x[1] > y[1];
  }
}

// node_modules/melange.js/caml_option.js
function some(x) {
  if (x === void 0) {
    return {
      MEL_PRIVATE_NESTED_SOME_NONE: 0
    };
  } else if (x !== null && x.MEL_PRIVATE_NESTED_SOME_NONE !== void 0) {
    return {
      MEL_PRIVATE_NESTED_SOME_NONE: x.MEL_PRIVATE_NESTED_SOME_NONE + 1 | 0
    };
  } else {
    return x;
  }
}
function nullable_to_opt(x) {
  if (x == null) {
    return;
  } else {
    return some(x);
  }
}
function valFromOption(x) {
  if (!(x !== null && x.MEL_PRIVATE_NESTED_SOME_NONE !== void 0)) {
    return x;
  }
  const depth = x.MEL_PRIVATE_NESTED_SOME_NONE;
  if (depth === 0) {
    return;
  } else {
    return {
      MEL_PRIVATE_NESTED_SOME_NONE: depth - 1 | 0
    };
  }
}

// node_modules/melange.js/caml_exceptions.js
var idMap = {};
function fresh(str) {
  const v = idMap[str];
  const id = v == null ? 1 : v + 1 | 0;
  idMap[str] = id;
  return id;
}
function create(str) {
  const id = fresh(str);
  return str + ("/" + id);
}
function caml_is_extension(e) {
  if (e == null) {
    return false;
  } else {
    return typeof e.MEL_EXN_ID === "string";
  }
}
function caml_exn_slot_name(x) {
  return x.MEL_EXN_ID;
}

// node_modules/melange.js/caml_js_exceptions.js
var MelangeError = (function MelangeError2(message, payload) {
  var cause = payload != null ? payload : { MEL_EXN_ID: message };
  var _this = Error.call(this, message, { cause });
  if (_this.cause == null) {
    Object.defineProperty(_this, "cause", {
      configurable: true,
      enumerable: false,
      writable: true,
      value: cause
    });
  }
  Object.defineProperty(_this, "name", {
    configurable: true,
    enumerable: false,
    writable: true,
    value: "MelangeError"
  });
  Object.assign(_this, cause);
  return _this;
});
MelangeError.prototype = Error.prototype;
function internalAnyToExn(any) {
  if (caml_is_extension(any)) {
    return any;
  }
  const exn = new MelangeError("Js__Js_exn.Error/1");
  exn["_1"] = any;
  return exn;
}
var internalToOCamlException = internalAnyToExn;

// node_modules/melange.js/caml_string.js
function get(s, i) {
  if (i >= s.length || i < 0) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "index out of bounds"
    });
  }
  return s.charCodeAt(i);
}

// node_modules/melange.js/caml_array.js
function sub(x, offset, len) {
  const result = new Array(len);
  let j = 0;
  let i = offset;
  while (j < len) {
    result[j] = x[i];
    j = j + 1 | 0;
    i = i + 1 | 0;
  }
  ;
  return result;
}
function set(xs, index, newval) {
  if (index < 0 || index >= xs.length) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "index out of bounds"
    });
  }
  xs[index] = newval;
}
function get2(xs, index) {
  if (index < 0 || index >= xs.length) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "index out of bounds"
    });
  }
  return xs[index];
}
function make(len, init3) {
  const b = new Array(len);
  for (let i = 0; i < len; ++i) {
    b[i] = init3;
  }
  return b;
}
function blit(a1, i1, a2, i2, len) {
  if (i2 <= i1) {
    for (let j = 0; j < len; ++j) {
      a2[j + i2 | 0] = a1[j + i1 | 0];
    }
    return;
  }
  for (let j$1 = len - 1 | 0; j$1 >= 0; --j$1) {
    a2[j$1 + i2 | 0] = a1[j$1 + i1 | 0];
  }
}

// node_modules/melange.js/curry.js
function app(_f, _args) {
  while (true) {
    const args = _args;
    const f = _f;
    const init_arity = f.length;
    const arity = init_arity === 0 ? 1 : init_arity;
    const len = args.length;
    const d = arity - len | 0;
    if (d === 0) {
      return f.apply(null, args);
    }
    if (d >= 0) {
      return function(x) {
        return app(f, args.concat([x]));
      };
    }
    _args = sub(args, arity, -d | 0);
    _f = f.apply(null, sub(args, 0, arity));
    continue;
  }
  ;
}
function _1(o, a0) {
  const arity = o.length;
  if (arity === 1) {
    return o(a0);
  } else {
    switch (arity) {
      case 1:
        return o(a0);
      case 2:
        return function(param) {
          return o(a0, param);
        };
      case 3:
        return function(param, param$1) {
          return o(a0, param, param$1);
        };
      case 4:
        return function(param, param$1, param$2) {
          return o(a0, param, param$1, param$2);
        };
      case 5:
        return function(param, param$1, param$2, param$3) {
          return o(a0, param, param$1, param$2, param$3);
        };
      case 6:
        return function(param, param$1, param$2, param$3, param$4) {
          return o(a0, param, param$1, param$2, param$3, param$4);
        };
      case 7:
        return function(param, param$1, param$2, param$3, param$4, param$5) {
          return o(a0, param, param$1, param$2, param$3, param$4, param$5);
        };
      default:
        return app(o, [a0]);
    }
  }
}
function _2(o, a0, a1) {
  const arity = o.length;
  if (arity === 2) {
    return o(a0, a1);
  } else {
    switch (arity) {
      case 1:
        return app(o(a0), [a1]);
      case 2:
        return o(a0, a1);
      case 3:
        return function(param) {
          return o(a0, a1, param);
        };
      case 4:
        return function(param, param$1) {
          return o(a0, a1, param, param$1);
        };
      case 5:
        return function(param, param$1, param$2) {
          return o(a0, a1, param, param$1, param$2);
        };
      case 6:
        return function(param, param$1, param$2, param$3) {
          return o(a0, a1, param, param$1, param$2, param$3);
        };
      case 7:
        return function(param, param$1, param$2, param$3, param$4) {
          return o(a0, a1, param, param$1, param$2, param$3, param$4);
        };
      default:
        return app(o, [
          a0,
          a1
        ]);
    }
  }
}
function __2(o) {
  const arity = o.length;
  if (arity === 2) {
    return o;
  } else {
    return function(a0, a1) {
      return _2(o, a0, a1);
    };
  }
}
function _5(o, a0, a1, a2, a3, a4) {
  const arity = o.length;
  if (arity === 5) {
    return o(a0, a1, a2, a3, a4);
  } else {
    switch (arity) {
      case 1:
        return app(o(a0), [
          a1,
          a2,
          a3,
          a4
        ]);
      case 2:
        return app(o(a0, a1), [
          a2,
          a3,
          a4
        ]);
      case 3:
        return app(o(a0, a1, a2), [
          a3,
          a4
        ]);
      case 4:
        return app(o(a0, a1, a2, a3), [a4]);
      case 5:
        return o(a0, a1, a2, a3, a4);
      case 6:
        return function(param) {
          return o(a0, a1, a2, a3, a4, param);
        };
      case 7:
        return function(param, param$1) {
          return o(a0, a1, a2, a3, a4, param, param$1);
        };
      default:
        return app(o, [
          a0,
          a1,
          a2,
          a3,
          a4
        ]);
    }
  }
}

// node_modules/melange.js/caml_obj.js
var for_in = (function(o, foo) {
  for (var x in o) {
    foo(x);
  }
});
function caml_equal(a, b) {
  if (a === b) {
    return true;
  }
  const a_type = typeof a;
  if (a_type === "string" || a_type === "number" || a_type === "bigint" || a_type === "boolean" || a_type === "undefined" || a === null) {
    return false;
  }
  const b_type = typeof b;
  if (a_type === "function" || b_type === "function") {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "equal: functional value"
    });
  }
  if (b_type === "number" || b_type === "bigint" || b_type === "undefined" || b === null) {
    return false;
  }
  const tag_a = a.TAG;
  const tag_b = b.TAG;
  if (tag_a === 248) {
    return a[1] === b[1];
  }
  if (tag_a === 251) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "equal: abstract value"
    });
  }
  if (tag_a !== tag_b) {
    return false;
  }
  const len_a = a.length | 0;
  const len_b = b.length | 0;
  if (len_a === len_b) {
    if (Array.isArray(a)) {
      let _i = 0;
      while (true) {
        const i = _i;
        if (i === len_a) {
          return true;
        }
        if (!caml_equal(a[i], b[i])) {
          return false;
        }
        _i = i + 1 | 0;
        continue;
      }
      ;
    } else if (a instanceof Date && b instanceof Date) {
      return !(a > b || a < b);
    } else {
      const result = {
        contents: true
      };
      const do_key_a = function(key) {
        if (!Object.prototype.hasOwnProperty.call(b, key)) {
          result.contents = false;
          return;
        }
      };
      const do_key_b = function(key) {
        if (!Object.prototype.hasOwnProperty.call(a, key) || !caml_equal(b[key], a[key])) {
          result.contents = false;
          return;
        }
      };
      for_in(a, do_key_a);
      if (result.contents) {
        for_in(b, do_key_b);
      }
      return result.contents;
    }
  } else {
    return false;
  }
}
function caml_notequal(a, b) {
  if ((typeof a === "number" || typeof a === "bigint") && (typeof b === "number" || typeof b === "bigint")) {
    return a !== b;
  } else {
    return !caml_equal(a, b);
  }
}

// node_modules/melange.js/caml_sys.js
var os_type = (function(_) {
  if (typeof process !== "undefined" && process.platform === "win32") {
    return "Win32";
  } else {
    return "Unix";
  }
});
function caml_sys_executable_name(param) {
  if (typeof process === "undefined") {
    return "";
  }
  const argv = process.argv;
  if (argv == null) {
    return "";
  } else {
    return argv[0];
  }
}

// node_modules/melange.js/caml_int64.js
var min_int = [
  -2147483648,
  0
];
var max_int = [
  2147483647,
  4294967295
];
var one = [
  0,
  1
];
var zero = [
  0,
  0
];
var neg_one = [
  -1,
  4294967295
];
function neg_signed(x) {
  return (x & -2147483648) !== 0;
}
function non_neg_signed(x) {
  return (x & -2147483648) === 0;
}
function neg(param) {
  const other_lo = (param[1] ^ -1) + 1 | 0;
  return [
    (param[0] ^ -1) + (other_lo === 0 ? 1 : 0) | 0,
    other_lo >>> 0
  ];
}
function add_aux(param, y_lo, y_hi) {
  const x_lo = param[1];
  const lo = x_lo + y_lo | 0;
  const overflow = neg_signed(x_lo) && (neg_signed(y_lo) || non_neg_signed(lo)) || neg_signed(y_lo) && non_neg_signed(lo) ? 1 : 0;
  return [
    param[0] + y_hi + overflow | 0,
    lo >>> 0
  ];
}
function add(self2, param) {
  return add_aux(self2, param[1], param[0]);
}
function sub_aux(x, lo, hi) {
  const y_lo = (lo ^ -1) + 1 >>> 0;
  const y_hi = (hi ^ -1) + (y_lo === 0 ? 1 : 0) | 0;
  return add_aux(x, y_lo, y_hi);
}
function sub2(self2, param) {
  return sub_aux(self2, param[1], param[0]);
}
function lsl_(x, numBits) {
  if (numBits === 0) {
    return x;
  }
  const lo = x[1];
  if (numBits >= 32) {
    return [
      lo << (numBits - 32 | 0),
      0
    ];
  } else {
    return [
      lo >>> (32 - numBits | 0) | x[0] << numBits,
      lo << numBits >>> 0
    ];
  }
}
function asr_(x, numBits) {
  if (numBits === 0) {
    return x;
  }
  const hi = x[0];
  if (numBits < 32) {
    return [
      hi >> numBits,
      (hi << (32 - numBits | 0) | x[1] >>> numBits) >>> 0
    ];
  } else {
    return [
      hi >= 0 ? 0 : -1,
      hi >> (numBits - 32 | 0) >>> 0
    ];
  }
}
function is_zero(param) {
  if (param[0] !== 0) {
    return false;
  } else {
    return param[1] === 0;
  }
}
function mul(_this, _other) {
  while (true) {
    const other = _other;
    const $$this = _this;
    let lo;
    const this_hi = $$this[0];
    let exit2 = 0;
    let exit$1 = 0;
    let exit$2 = 0;
    if (this_hi !== 0) {
      exit$2 = 4;
    } else {
      if ($$this[1] === 0) {
        return zero;
      }
      exit$2 = 4;
    }
    if (exit$2 === 4) {
      if (other[0] !== 0) {
        exit$1 = 3;
      } else {
        if (other[1] === 0) {
          return zero;
        }
        exit$1 = 3;
      }
    }
    if (exit$1 === 3) {
      if (this_hi !== -2147483648 || $$this[1] !== 0) {
        exit2 = 2;
      } else {
        lo = other[1];
      }
    }
    if (exit2 === 2) {
      const other_hi = other[0];
      const lo$1 = $$this[1];
      let exit$3 = 0;
      if (other_hi !== -2147483648 || other[1] !== 0) {
        exit$3 = 3;
      } else {
        lo = lo$1;
      }
      if (exit$3 === 3) {
        const other_lo = other[1];
        if (this_hi < 0) {
          if (other_hi >= 0) {
            return neg(mul(neg($$this), other));
          }
          _other = neg(other);
          _this = neg($$this);
          continue;
        }
        if (other_hi < 0) {
          return neg(mul($$this, neg(other)));
        }
        const a48 = this_hi >>> 16;
        const a32 = this_hi & 65535;
        const a16 = lo$1 >>> 16;
        const a00 = lo$1 & 65535;
        const b48 = other_hi >>> 16;
        const b32 = other_hi & 65535;
        const b16 = other_lo >>> 16;
        const b00 = other_lo & 65535;
        let c48 = 0;
        let c32 = 0;
        let c16 = 0;
        const c00 = a00 * b00;
        c16 = (c00 >>> 16) + a16 * b00;
        c32 = c16 >>> 16;
        c16 = (c16 & 65535) + a00 * b16;
        c32 = c32 + (c16 >>> 16) + a32 * b00;
        c48 = c32 >>> 16;
        c32 = (c32 & 65535) + a16 * b16;
        c48 = c48 + (c32 >>> 16);
        c32 = (c32 & 65535) + a00 * b32;
        c48 = c48 + (c32 >>> 16);
        c32 = c32 & 65535;
        c48 = c48 + (a48 * b00 + a32 * b16 + a16 * b32 + a00 * b48) & 65535;
        return [
          c32 | c48 << 16,
          (c00 & 65535 | (c16 & 65535) << 16) >>> 0
        ];
      }
    }
    if ((lo & 1) === 0) {
      return zero;
    } else {
      return min_int;
    }
  }
  ;
}
function to_float(param) {
  return param[0] * 4294967296 + param[1];
}
function of_float(x) {
  if (isNaN(x) || !isFinite(x)) {
    return zero;
  }
  if (x <= -9223372036854776e3) {
    return min_int;
  }
  if (x + 1 >= 9223372036854776e3) {
    return max_int;
  }
  if (x < 0) {
    return neg(of_float(-x));
  }
  const hi = x / 4294967296 | 0;
  const lo = x % 4294967296 | 0;
  return [
    hi,
    lo >>> 0
  ];
}
function isSafeInteger(param) {
  const hi = param[0];
  const top11Bits = hi >> 21;
  if (top11Bits === 0) {
    return true;
  } else if (top11Bits === -1) {
    return !(param[1] === 0 && hi === -2097152);
  } else {
    return false;
  }
}
function to_string(self2) {
  if (isSafeInteger(self2)) {
    return String(to_float(self2));
  }
  if (self2[0] < 0) {
    if (i64_eq(self2, min_int)) {
      return "-9223372036854775808";
    } else {
      return "-" + to_string(neg(self2));
    }
  }
  const approx_div1 = of_float(Math.floor(to_float(self2) / 10));
  const lo = approx_div1[1];
  const hi = approx_div1[0];
  const match = sub_aux(sub_aux(self2, lo << 3, lo >>> 29 | hi << 3), lo << 1, lo >>> 31 | hi << 1);
  const rem_lo = match[1];
  const rem_hi = match[0];
  if (rem_lo === 0 && rem_hi === 0) {
    return to_string(approx_div1) + "0";
  }
  if (rem_hi < 0) {
    const rem_lo$1 = (rem_lo ^ -1) + 1 >>> 0;
    const delta = Math.ceil(rem_lo$1 / 10);
    const remainder = 10 * delta - rem_lo$1;
    return to_string(sub_aux(approx_div1, delta | 0, 0)) + String(remainder | 0);
  }
  const delta$1 = Math.floor(rem_lo / 10);
  const remainder$1 = rem_lo - 10 * delta$1;
  return to_string(add_aux(approx_div1, delta$1 | 0, 0)) + String(remainder$1 | 0);
}
function div(_self, _other) {
  while (true) {
    const other = _other;
    const self2 = _self;
    let exit2 = 0;
    if (other[0] !== 0 || other[1] !== 0) {
      exit2 = 1;
    } else {
      throw new MelangeError("Division_by_zero", {
        MEL_EXN_ID: "Division_by_zero"
      });
    }
    if (exit2 === 1) {
      const self_hi = self2[0];
      let exit$1 = 0;
      if (self_hi !== -2147483648) {
        if (self_hi !== 0) {
          exit$1 = 2;
        } else {
          if (self2[1] === 0) {
            return zero;
          }
          exit$1 = 2;
        }
      } else if (self2[1] !== 0) {
        exit$1 = 2;
      } else {
        if (i64_eq(other, one) || i64_eq(other, neg_one)) {
          return self2;
        }
        if (i64_eq(other, min_int)) {
          return one;
        }
        const half_this = asr_(self2, 1);
        const approx = lsl_(div(half_this, other), 1);
        let exit$2 = 0;
        if (approx[0] !== 0) {
          exit$2 = 3;
        } else {
          if (approx[1] === 0) {
            if (other[0] < 0) {
              return one;
            } else {
              return neg(one);
            }
          }
          exit$2 = 3;
        }
        if (exit$2 === 3) {
          const rem = sub2(self2, mul(other, approx));
          return add(approx, div(rem, other));
        }
      }
      if (exit$1 === 2) {
        const other_hi = other[0];
        let exit$3 = 0;
        if (other_hi !== -2147483648) {
          exit$3 = 3;
        } else {
          if (other[1] === 0) {
            return zero;
          }
          exit$3 = 3;
        }
        if (exit$3 === 3) {
          if (self_hi < 0) {
            if (other_hi >= 0) {
              return neg(div(neg(self2), other));
            }
            _other = neg(other);
            _self = neg(self2);
            continue;
          }
          if (other_hi < 0) {
            return neg(div(self2, neg(other)));
          }
          let res = zero;
          let rem$1 = self2;
          while (i64_ge(rem$1, other)) {
            const b = Math.floor(to_float(rem$1) / to_float(other));
            let approx$1 = 1 > b ? 1 : b;
            const log2 = Math.ceil(Math.log(approx$1) / Math.LN2);
            const delta = log2 <= 48 ? 1 : Math.pow(2, log2 - 48);
            let approxRes = of_float(approx$1);
            let approxRem = mul(approxRes, other);
            while (approxRem[0] < 0 || i64_gt(approxRem, rem$1)) {
              approx$1 = approx$1 - delta;
              approxRes = of_float(approx$1);
              approxRem = mul(approxRes, other);
            }
            ;
            if (is_zero(approxRes)) {
              approxRes = one;
            }
            res = add(res, approxRes);
            rem$1 = sub2(rem$1, approxRem);
          }
          ;
          return res;
        }
      }
    }
  }
  ;
}
function div_mod(self2, other) {
  const quotient = div(self2, other);
  return [
    quotient,
    sub2(self2, mul(quotient, other))
  ];
}
function to_int32(x) {
  return x[1] | 0;
}
function to_hex(x) {
  const x_lo = x[1];
  const x_hi = x[0];
  const aux = function(v) {
    return (v >>> 0).toString(16);
  };
  if (x_hi === 0 && x_lo === 0) {
    return "0";
  }
  if (x_lo === 0) {
    return aux(x_hi) + "00000000";
  }
  if (x_hi === 0) {
    return aux(x_lo);
  }
  const lo = aux(x_lo);
  const pad = 8 - lo.length | 0;
  if (pad <= 0) {
    return aux(x_hi) + lo;
  } else {
    return aux(x_hi) + ("0".repeat(pad) + lo);
  }
}
function discard_sign(x) {
  return [
    2147483647 & x[0],
    x[1]
  ];
}

// node_modules/melange.js/caml_bytes.js
function set2(s, i, ch) {
  if (i < 0 || i >= s.length) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "index out of bounds"
    });
  }
  s[i] = ch;
}
function caml_fill_bytes(s, i, l, c) {
  if (l <= 0) {
    return;
  }
  for (let k = i, k_finish = l + i | 0; k < k_finish; ++k) {
    s[k] = c;
  }
}
function caml_create_bytes(len) {
  if (len < 0) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "String.create"
    });
  }
  const result = new Array(len);
  for (let i = 0; i < len; ++i) {
    result[i] = /* '\000' */
    0;
  }
  return result;
}
function caml_blit_bytes(s1, i1, s2, i2, len) {
  if (len <= 0) {
    return;
  }
  if (s1 === s2) {
    if (i1 < i2) {
      const range_a = (s1.length - i2 | 0) - 1 | 0;
      const range_b = len - 1 | 0;
      const range = range_a > range_b ? range_b : range_a;
      for (let j = range; j >= 0; --j) {
        s1[i2 + j | 0] = s1[i1 + j | 0];
      }
      return;
    }
    if (i1 <= i2) {
      return;
    }
    const range_a$1 = (s1.length - i1 | 0) - 1 | 0;
    const range_b$1 = len - 1 | 0;
    const range$1 = range_a$1 > range_b$1 ? range_b$1 : range_a$1;
    for (let k = 0; k <= range$1; ++k) {
      s1[i2 + k | 0] = s1[i1 + k | 0];
    }
    return;
  }
  const off1 = s1.length - i1 | 0;
  if (len <= off1) {
    for (let i = 0; i < len; ++i) {
      s2[i2 + i | 0] = s1[i1 + i | 0];
    }
    return;
  }
  for (let i$1 = 0; i$1 < off1; ++i$1) {
    s2[i2 + i$1 | 0] = s1[i1 + i$1 | 0];
  }
  for (let i$2 = off1; i$2 < len; ++i$2) {
    s2[i2 + i$2 | 0] = /* '\000' */
    0;
  }
}
function bytes_to_string(a) {
  let i = 0;
  let len = a.length;
  let s = "";
  let s_len = len;
  if (i === 0 && len <= 4096 && len === a.length) {
    return String.fromCharCode.apply(null, a);
  }
  let offset = 0;
  while (s_len > 0) {
    const next = s_len < 1024 ? s_len : 1024;
    const tmp_bytes = new Array(next);
    for (let k = 0; k < next; ++k) {
      tmp_bytes[k] = a[k + offset | 0];
    }
    s = s + String.fromCharCode.apply(null, tmp_bytes);
    s_len = s_len - next | 0;
    offset = offset + next | 0;
  }
  ;
  return s;
}
function caml_blit_string(s1, i1, s2, i2, len) {
  if (len <= 0) {
    return;
  }
  const off1 = s1.length - i1 | 0;
  if (len <= off1) {
    for (let i = 0; i < len; ++i) {
      s2[i2 + i | 0] = s1.charCodeAt(i1 + i | 0);
    }
    return;
  }
  for (let i$1 = 0; i$1 < off1; ++i$1) {
    s2[i2 + i$1 | 0] = s1.charCodeAt(i1 + i$1 | 0);
  }
  for (let i$2 = off1; i$2 < len; ++i$2) {
    s2[i2 + i$2 | 0] = /* '\000' */
    0;
  }
}
function bytes_of_string(s) {
  const len = s.length;
  const res = new Array(len);
  for (let i = 0; i < len; ++i) {
    res[i] = s.charCodeAt(i);
  }
  return res;
}

// node_modules/melange.js/caml_format.js
function parse_digit(c) {
  if (c >= 65) {
    if (c >= 97) {
      if (c >= 123) {
        return -1;
      } else {
        return c - 87 | 0;
      }
    } else if (c >= 91) {
      return -1;
    } else {
      return c - 55 | 0;
    }
  } else if (c > 57 || c < 48) {
    return -1;
  } else {
    return c - /* '0' */
    48 | 0;
  }
}
function int_of_string_base(param) {
  switch (param) {
    case /* Oct */
    0:
      return 8;
    case /* Hex */
    1:
      return 16;
    case /* Dec */
    2:
      return 10;
    case /* Bin */
    3:
      return 2;
  }
}
function parse_sign_and_base(s) {
  let sign = 1;
  let base = (
    /* Dec */
    2
  );
  let i = 0;
  const match = s.charCodeAt(i);
  switch (match) {
    case 43:
      i = i + 1 | 0;
      break;
    case 45:
      sign = -1;
      i = i + 1 | 0;
      break;
  }
  if (s[i] === "0") {
    const match$1 = s.charCodeAt(i + 1 | 0);
    if (match$1 >= 89) {
      if (match$1 >= 111) {
        if (match$1 < 121) {
          switch (match$1) {
            case 111:
              base = /* Oct */
              0;
              i = i + 2 | 0;
              break;
            case 117:
              i = i + 2 | 0;
              break;
            case 112:
            case 113:
            case 114:
            case 115:
            case 116:
            case 118:
            case 119:
              break;
            case 120:
              base = /* Hex */
              1;
              i = i + 2 | 0;
              break;
          }
        }
      } else if (match$1 === 98) {
        base = /* Bin */
        3;
        i = i + 2 | 0;
      }
    } else if (match$1 !== 66) {
      if (match$1 >= 79) {
        switch (match$1) {
          case 79:
            base = /* Oct */
            0;
            i = i + 2 | 0;
            break;
          case 85:
            i = i + 2 | 0;
            break;
          case 80:
          case 81:
          case 82:
          case 83:
          case 84:
          case 86:
          case 87:
            break;
          case 88:
            base = /* Hex */
            1;
            i = i + 2 | 0;
            break;
        }
      }
    } else {
      base = /* Bin */
      3;
      i = i + 2 | 0;
    }
  }
  return [
    i,
    sign,
    base
  ];
}
function caml_int_of_string(s) {
  const match = parse_sign_and_base(s);
  const i = match[0];
  const base = int_of_string_base(match[2]);
  const threshold = 4294967295;
  const len = s.length;
  const c = i < len ? s.charCodeAt(i) : (
    /* '\000' */
    0
  );
  const d = parse_digit(c);
  if (d < 0 || d >= base) {
    throw new MelangeError("Failure", {
      MEL_EXN_ID: "Failure",
      _1: "int_of_string"
    });
  }
  const aux = function(_acc, _k) {
    while (true) {
      const k = _k;
      const acc = _acc;
      if (k === len) {
        return acc;
      }
      const a = s.charCodeAt(k);
      if (a === /* '_' */
      95) {
        _k = k + 1 | 0;
        continue;
      }
      const v = parse_digit(a);
      if (v < 0 || v >= base) {
        throw new MelangeError("Failure", {
          MEL_EXN_ID: "Failure",
          _1: "int_of_string"
        });
      }
      const acc$1 = base * acc + v;
      if (acc$1 > threshold) {
        throw new MelangeError("Failure", {
          MEL_EXN_ID: "Failure",
          _1: "int_of_string"
        });
      }
      _k = k + 1 | 0;
      _acc = acc$1;
      continue;
    }
    ;
  };
  const res = match[1] * aux(d, i + 1 | 0);
  const or_res = res | 0;
  if (base === 10 && res !== or_res) {
    throw new MelangeError("Failure", {
      MEL_EXN_ID: "Failure",
      _1: "int_of_string"
    });
  }
  return or_res;
}
function int_of_base(param) {
  switch (param) {
    case /* Oct */
    0:
      return 8;
    case /* Hex */
    1:
      return 16;
    case /* Dec */
    2:
      return 10;
  }
}
function lowercase(c) {
  if (c >= /* 'A' */
  65 && c <= /* 'Z' */
  90 || c >= /* '\192' */
  192 && c <= /* '\214' */
  214 || c >= /* '\216' */
  216 && c <= /* '\222' */
  222) {
    return c + 32 | 0;
  } else {
    return c;
  }
}
function parse_format(fmt) {
  const len = fmt.length;
  if (len > 31) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "format_int: format too long"
    });
  }
  let f = {
    justify: "+",
    signstyle: "-",
    filter: " ",
    alternate: false,
    base: (
      /* Dec */
      2
    ),
    signedconv: false,
    width: 0,
    uppercase: false,
    sign: 1,
    prec: -1,
    conv: "f"
  };
  let _i = 0;
  while (true) {
    const i = _i;
    if (i >= len) {
      return f;
    }
    const c = fmt.charCodeAt(i);
    let exit2 = 0;
    if (c >= 69) {
      if (c >= 88) {
        if (c >= 121) {
          exit2 = 1;
        } else {
          switch (c) {
            case 88:
              f.base = /* Hex */
              1;
              f.uppercase = true;
              _i = i + 1 | 0;
              continue;
            case 101:
            case 102:
            case 103:
              exit2 = 5;
              break;
            case 100:
            case 105:
              exit2 = 4;
              break;
            case 111:
              f.base = /* Oct */
              0;
              _i = i + 1 | 0;
              continue;
            case 117:
              f.base = /* Dec */
              2;
              _i = i + 1 | 0;
              continue;
            case 89:
            case 90:
            case 91:
            case 92:
            case 93:
            case 94:
            case 95:
            case 96:
            case 97:
            case 98:
            case 99:
            case 104:
            case 106:
            case 107:
            case 108:
            case 109:
            case 110:
            case 112:
            case 113:
            case 114:
            case 115:
            case 116:
            case 118:
            case 119:
              exit2 = 1;
              break;
            case 120:
              f.base = /* Hex */
              1;
              _i = i + 1 | 0;
              continue;
          }
        }
      } else if (c >= 72) {
        exit2 = 1;
      } else {
        f.signedconv = true;
        f.uppercase = true;
        f.conv = String.fromCharCode(lowercase(c));
        _i = i + 1 | 0;
        continue;
      }
    } else {
      switch (c) {
        case 35:
          f.alternate = true;
          _i = i + 1 | 0;
          continue;
        case 32:
        case 43:
          exit2 = 2;
          break;
        case 45:
          f.justify = "-";
          _i = i + 1 | 0;
          continue;
        case 46:
          f.prec = 0;
          let j = i + 1 | 0;
          while ((function() {
            const w = fmt.charCodeAt(j) - /* '0' */
            48 | 0;
            return w >= 0 && w <= 9;
          })()) {
            f.prec = (Math.imul(f.prec, 10) + fmt.charCodeAt(j) | 0) - /* '0' */
            48 | 0;
            j = j + 1 | 0;
          }
          ;
          _i = j;
          continue;
        case 48:
          f.filter = "0";
          _i = i + 1 | 0;
          continue;
        case 49:
        case 50:
        case 51:
        case 52:
        case 53:
        case 54:
        case 55:
        case 56:
        case 57:
          exit2 = 3;
          break;
        default:
          exit2 = 1;
      }
    }
    switch (exit2) {
      case 1:
        _i = i + 1 | 0;
        continue;
      case 2:
        f.signstyle = String.fromCharCode(c);
        _i = i + 1 | 0;
        continue;
      case 3:
        f.width = 0;
        let j$1 = i;
        while ((function() {
          const w = fmt.charCodeAt(j$1) - /* '0' */
          48 | 0;
          return w >= 0 && w <= 9;
        })()) {
          f.width = (Math.imul(f.width, 10) + fmt.charCodeAt(j$1) | 0) - /* '0' */
          48 | 0;
          j$1 = j$1 + 1 | 0;
        }
        ;
        _i = j$1;
        continue;
      case 4:
        f.signedconv = true;
        f.base = /* Dec */
        2;
        _i = i + 1 | 0;
        continue;
      case 5:
        f.signedconv = true;
        f.conv = String.fromCharCode(c);
        _i = i + 1 | 0;
        continue;
    }
  }
  ;
}
function finish_formatting(config, rawbuffer) {
  const justify = config.justify;
  const signstyle = config.signstyle;
  const filter2 = config.filter;
  const alternate = config.alternate;
  const base = config.base;
  const signedconv = config.signedconv;
  const width = config.width;
  const uppercase = config.uppercase;
  const sign = config.sign;
  let len = rawbuffer.length;
  if (signedconv && (sign < 0 || signstyle !== "-")) {
    len = len + 1 | 0;
  }
  if (alternate) {
    if (base === /* Oct */
    0) {
      len = len + 1 | 0;
    } else if (base === /* Hex */
    1) {
      len = len + 2 | 0;
    }
  }
  let buffer = "";
  if (justify === "+" && filter2 === " ") {
    for (let _for = len; _for < width; ++_for) {
      buffer = buffer + filter2;
    }
  }
  if (signedconv) {
    if (sign < 0) {
      buffer = buffer + "-";
    } else if (signstyle !== "-") {
      buffer = buffer + signstyle;
    }
  }
  if (alternate && base === /* Oct */
  0) {
    buffer = buffer + "0";
  }
  if (alternate && base === /* Hex */
  1) {
    buffer = buffer + "0x";
  }
  if (justify === "+" && filter2 === "0") {
    for (let _for$1 = len; _for$1 < width; ++_for$1) {
      buffer = buffer + filter2;
    }
  }
  buffer = uppercase ? buffer + rawbuffer.toUpperCase() : buffer + rawbuffer;
  if (justify === "-") {
    for (let _for$2 = len; _for$2 < width; ++_for$2) {
      buffer = buffer + " ";
    }
  }
  return buffer;
}
function caml_format_int(fmt, i) {
  if (fmt === "%d") {
    return String(i);
  }
  const f = parse_format(fmt);
  const i$1 = i < 0 ? f.signedconv ? (f.sign = -1, -i >>> 0) : i >>> 0 : i;
  let s = i$1.toString(int_of_base(f.base));
  if (f.prec >= 0) {
    f.filter = " ";
    const n = f.prec - s.length | 0;
    if (n > 0) {
      s = "0".repeat(n) + s;
    }
  }
  return finish_formatting(f, s);
}
function dec_of_pos_int64(x) {
  if (!i64_lt(x, zero)) {
    return to_string(x);
  }
  const wbase = [
    0,
    10
  ];
  const y = discard_sign(x);
  const match = div_mod(y, wbase);
  const match$1 = div_mod(add([
    0,
    8
  ], match[1]), wbase);
  const quotient = add(add([
    214748364,
    3435973836
  ], match[0]), match$1[0]);
  return to_string(quotient) + "0123456789"[to_int32(match$1[1])];
}
function oct_of_int64(x) {
  let s = "";
  const wbase = [
    0,
    8
  ];
  const cvtbl = "01234567";
  if (i64_lt(x, zero)) {
    const y = discard_sign(x);
    const match = div_mod(y, wbase);
    let quotient = add([
      268435456,
      0
    ], match[0]);
    let modulus = match[1];
    s = cvtbl[to_int32(modulus)] + s;
    while (i64_neq(quotient, zero)) {
      const match$1 = div_mod(quotient, wbase);
      quotient = match$1[0];
      modulus = match$1[1];
      s = cvtbl[to_int32(modulus)] + s;
    }
    ;
  } else {
    const match$2 = div_mod(x, wbase);
    let quotient$1 = match$2[0];
    let modulus$1 = match$2[1];
    s = cvtbl[to_int32(modulus$1)] + s;
    while (i64_neq(quotient$1, zero)) {
      const match$3 = div_mod(quotient$1, wbase);
      quotient$1 = match$3[0];
      modulus$1 = match$3[1];
      s = cvtbl[to_int32(modulus$1)] + s;
    }
    ;
  }
  return s;
}
function caml_int64_format(fmt, x) {
  if (fmt === "%d") {
    return to_string(x);
  }
  const f = parse_format(fmt);
  const x$1 = f.signedconv && i64_lt(x, zero) ? (f.sign = -1, neg(x)) : x;
  const match = f.base;
  let s;
  switch (match) {
    case /* Oct */
    0:
      s = oct_of_int64(x$1);
      break;
    case /* Hex */
    1:
      s = to_hex(x$1);
      break;
    case /* Dec */
    2:
      s = dec_of_pos_int64(x$1);
      break;
  }
  let fill_s;
  if (f.prec >= 0) {
    f.filter = " ";
    const n = f.prec - s.length | 0;
    fill_s = n > 0 ? "0".repeat(n) + s : s;
  } else {
    fill_s = s;
  }
  return finish_formatting(f, fill_s);
}
function caml_format_float(fmt, x) {
  const f = parse_format(fmt);
  const prec = f.prec < 0 ? 6 : f.prec;
  const x$1 = x < 0 ? (f.sign = -1, -x) : x;
  let s = "";
  if (isNaN(x$1)) {
    s = "nan";
    f.filter = " ";
  } else if (isFinite(x$1)) {
    const match = f.conv;
    switch (match) {
      case "e":
        s = x$1.toExponential(prec);
        const i = s.length;
        if (s[i - 3 | 0] === "e") {
          s = s.slice(0, i - 1 | 0) + ("0" + s.slice(i - 1 | 0));
        }
        break;
      case "f":
        s = x$1.toFixed(prec);
        break;
      case "g":
        const prec$1 = prec !== 0 ? prec : 1;
        s = x$1.toExponential(prec$1 - 1 | 0);
        const j = s.indexOf("e");
        const exp = Number(s.slice(j + 1 | 0)) | 0;
        if (exp < -4 || x$1 >= 1e21 || x$1.toFixed().length > prec$1) {
          let i$1 = j - 1 | 0;
          while (s[i$1] === "0") {
            i$1 = i$1 - 1 | 0;
          }
          ;
          if (s[i$1] === ".") {
            i$1 = i$1 - 1 | 0;
          }
          s = s.slice(0, i$1 + 1 | 0) + s.slice(j);
          const i$2 = s.length;
          if (s[i$2 - 3 | 0] === "e") {
            s = s.slice(0, i$2 - 1 | 0) + ("0" + s.slice(i$2 - 1 | 0));
          }
        } else {
          let p = prec$1;
          if (exp < 0) {
            p = p - (exp + 1 | 0) | 0;
            s = x$1.toFixed(p);
          } else {
            while ((function() {
              s = x$1.toFixed(p);
              return s.length > (prec$1 + 1 | 0);
            })()) {
              p = p - 1 | 0;
            }
            ;
          }
          if (p !== 0) {
            let k = s.length - 1 | 0;
            while (s[k] === "0") {
              k = k - 1 | 0;
            }
            ;
            if (s[k] === ".") {
              k = k - 1 | 0;
            }
            s = s.slice(0, k + 1 | 0);
          }
        }
        break;
    }
  } else {
    s = "inf";
    f.filter = " ";
  }
  return finish_formatting(f, s);
}
var caml_hexstring_of_float = (function(x, prec, style) {
  if (!isFinite(x)) {
    if (isNaN(x)) return "nan";
    return x > 0 ? "infinity" : "-infinity";
  }
  var sign = x == 0 && 1 / x == -Infinity ? 1 : x >= 0 ? 0 : 1;
  if (sign) x = -x;
  var exp = 0;
  if (x == 0) {
  } else if (x < 1) {
    while (x < 1 && exp > -1022) {
      x *= 2;
      exp--;
    }
  } else {
    while (x >= 2) {
      x /= 2;
      exp++;
    }
  }
  var exp_sign = exp < 0 ? "" : "+";
  var sign_str = "";
  if (sign) sign_str = "-";
  else {
    switch (style) {
      case 43:
        sign_str = "+";
        break;
      case 32:
        sign_str = " ";
        break;
      default:
        break;
    }
  }
  if (prec >= 0 && prec < 13) {
    var cst = Math.pow(2, prec * 4);
    x = Math.round(x * cst) / cst;
  }
  var x_str = x.toString(16);
  if (prec >= 0) {
    var idx = x_str.indexOf(".");
    if (idx < 0) {
      x_str += "." + "0".repeat(prec);
    } else {
      var size = idx + 1 + prec;
      if (x_str.length < size)
        x_str += "0".repeat(size - x_str.length);
      else
        x_str = x_str.substr(0, size);
    }
  }
  return sign_str + "0x" + x_str + "p" + exp_sign + exp.toString(10);
});
var caml_nativeint_format = caml_format_int;
var caml_int32_format = caml_format_int;

// node_modules/melange/camlinternalFormatBasics.js
function erase_rel(rest) {
  if (
    /* tag */
    typeof rest === "number" || typeof rest === "string"
  ) {
    return (
      /* End_of_fmtty */
      0
    );
  }
  switch (rest.TAG) {
    case /* Char_ty */
    0:
      return {
        TAG: (
          /* Char_ty */
          0
        ),
        _0: erase_rel(rest._0)
      };
    case /* String_ty */
    1:
      return {
        TAG: (
          /* String_ty */
          1
        ),
        _0: erase_rel(rest._0)
      };
    case /* Int_ty */
    2:
      return {
        TAG: (
          /* Int_ty */
          2
        ),
        _0: erase_rel(rest._0)
      };
    case /* Int32_ty */
    3:
      return {
        TAG: (
          /* Int32_ty */
          3
        ),
        _0: erase_rel(rest._0)
      };
    case /* Nativeint_ty */
    4:
      return {
        TAG: (
          /* Nativeint_ty */
          4
        ),
        _0: erase_rel(rest._0)
      };
    case /* Int64_ty */
    5:
      return {
        TAG: (
          /* Int64_ty */
          5
        ),
        _0: erase_rel(rest._0)
      };
    case /* Float_ty */
    6:
      return {
        TAG: (
          /* Float_ty */
          6
        ),
        _0: erase_rel(rest._0)
      };
    case /* Bool_ty */
    7:
      return {
        TAG: (
          /* Bool_ty */
          7
        ),
        _0: erase_rel(rest._0)
      };
    case /* Format_arg_ty */
    8:
      return {
        TAG: (
          /* Format_arg_ty */
          8
        ),
        _0: rest._0,
        _1: erase_rel(rest._1)
      };
    case /* Format_subst_ty */
    9:
      const ty1 = rest._0;
      return {
        TAG: (
          /* Format_subst_ty */
          9
        ),
        _0: ty1,
        _1: ty1,
        _2: erase_rel(rest._2)
      };
    case /* Alpha_ty */
    10:
      return {
        TAG: (
          /* Alpha_ty */
          10
        ),
        _0: erase_rel(rest._0)
      };
    case /* Theta_ty */
    11:
      return {
        TAG: (
          /* Theta_ty */
          11
        ),
        _0: erase_rel(rest._0)
      };
    case /* Any_ty */
    12:
      return {
        TAG: (
          /* Any_ty */
          12
        ),
        _0: erase_rel(rest._0)
      };
    case /* Reader_ty */
    13:
      return {
        TAG: (
          /* Reader_ty */
          13
        ),
        _0: erase_rel(rest._0)
      };
    case /* Ignored_reader_ty */
    14:
      return {
        TAG: (
          /* Ignored_reader_ty */
          14
        ),
        _0: erase_rel(rest._0)
      };
  }
}
function concat_fmtty(fmtty1, fmtty2) {
  if (
    /* tag */
    typeof fmtty1 === "number" || typeof fmtty1 === "string"
  ) {
    return fmtty2;
  }
  switch (fmtty1.TAG) {
    case /* Char_ty */
    0:
      return {
        TAG: (
          /* Char_ty */
          0
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* String_ty */
    1:
      return {
        TAG: (
          /* String_ty */
          1
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Int_ty */
    2:
      return {
        TAG: (
          /* Int_ty */
          2
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Int32_ty */
    3:
      return {
        TAG: (
          /* Int32_ty */
          3
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Nativeint_ty */
    4:
      return {
        TAG: (
          /* Nativeint_ty */
          4
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Int64_ty */
    5:
      return {
        TAG: (
          /* Int64_ty */
          5
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Float_ty */
    6:
      return {
        TAG: (
          /* Float_ty */
          6
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Bool_ty */
    7:
      return {
        TAG: (
          /* Bool_ty */
          7
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Format_arg_ty */
    8:
      return {
        TAG: (
          /* Format_arg_ty */
          8
        ),
        _0: fmtty1._0,
        _1: concat_fmtty(fmtty1._1, fmtty2)
      };
    case /* Format_subst_ty */
    9:
      return {
        TAG: (
          /* Format_subst_ty */
          9
        ),
        _0: fmtty1._0,
        _1: fmtty1._1,
        _2: concat_fmtty(fmtty1._2, fmtty2)
      };
    case /* Alpha_ty */
    10:
      return {
        TAG: (
          /* Alpha_ty */
          10
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Theta_ty */
    11:
      return {
        TAG: (
          /* Theta_ty */
          11
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Any_ty */
    12:
      return {
        TAG: (
          /* Any_ty */
          12
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Reader_ty */
    13:
      return {
        TAG: (
          /* Reader_ty */
          13
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
    case /* Ignored_reader_ty */
    14:
      return {
        TAG: (
          /* Ignored_reader_ty */
          14
        ),
        _0: concat_fmtty(fmtty1._0, fmtty2)
      };
  }
}
function concat_fmt(fmt1, fmt2) {
  if (
    /* tag */
    typeof fmt1 === "number" || typeof fmt1 === "string"
  ) {
    return fmt2;
  }
  switch (fmt1.TAG) {
    case /* Char */
    0:
      return {
        TAG: (
          /* Char */
          0
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* Caml_char */
    1:
      return {
        TAG: (
          /* Caml_char */
          1
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* String */
    2:
      return {
        TAG: (
          /* String */
          2
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Caml_string */
    3:
      return {
        TAG: (
          /* Caml_string */
          3
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Int */
    4:
      return {
        TAG: (
          /* Int */
          4
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: fmt1._2,
        _3: concat_fmt(fmt1._3, fmt2)
      };
    case /* Int32 */
    5:
      return {
        TAG: (
          /* Int32 */
          5
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: fmt1._2,
        _3: concat_fmt(fmt1._3, fmt2)
      };
    case /* Nativeint */
    6:
      return {
        TAG: (
          /* Nativeint */
          6
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: fmt1._2,
        _3: concat_fmt(fmt1._3, fmt2)
      };
    case /* Int64 */
    7:
      return {
        TAG: (
          /* Int64 */
          7
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: fmt1._2,
        _3: concat_fmt(fmt1._3, fmt2)
      };
    case /* Float */
    8:
      return {
        TAG: (
          /* Float */
          8
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: fmt1._2,
        _3: concat_fmt(fmt1._3, fmt2)
      };
    case /* Bool */
    9:
      return {
        TAG: (
          /* Bool */
          9
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Flush */
    10:
      return {
        TAG: (
          /* Flush */
          10
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* String_literal */
    11:
      return {
        TAG: (
          /* String_literal */
          11
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Char_literal */
    12:
      return {
        TAG: (
          /* Char_literal */
          12
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Format_arg */
    13:
      return {
        TAG: (
          /* Format_arg */
          13
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: concat_fmt(fmt1._2, fmt2)
      };
    case /* Format_subst */
    14:
      return {
        TAG: (
          /* Format_subst */
          14
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: concat_fmt(fmt1._2, fmt2)
      };
    case /* Alpha */
    15:
      return {
        TAG: (
          /* Alpha */
          15
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* Theta */
    16:
      return {
        TAG: (
          /* Theta */
          16
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* Formatting_lit */
    17:
      return {
        TAG: (
          /* Formatting_lit */
          17
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Formatting_gen */
    18:
      return {
        TAG: (
          /* Formatting_gen */
          18
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Reader */
    19:
      return {
        TAG: (
          /* Reader */
          19
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* Scan_char_set */
    20:
      return {
        TAG: (
          /* Scan_char_set */
          20
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: concat_fmt(fmt1._2, fmt2)
      };
    case /* Scan_get_counter */
    21:
      return {
        TAG: (
          /* Scan_get_counter */
          21
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Scan_next_char */
    22:
      return {
        TAG: (
          /* Scan_next_char */
          22
        ),
        _0: concat_fmt(fmt1._0, fmt2)
      };
    case /* Ignored_param */
    23:
      return {
        TAG: (
          /* Ignored_param */
          23
        ),
        _0: fmt1._0,
        _1: concat_fmt(fmt1._1, fmt2)
      };
    case /* Custom */
    24:
      return {
        TAG: (
          /* Custom */
          24
        ),
        _0: fmt1._0,
        _1: fmt1._1,
        _2: concat_fmt(fmt1._2, fmt2)
      };
  }
}

// node_modules/melange/stdlib.js
function failwith(s) {
  throw new MelangeError("Failure", {
    MEL_EXN_ID: "Failure",
    _1: s
  });
}
var Failure = "Failure";
function abs(x) {
  if (x >= 0) {
    return x;
  } else {
    return -x | 0;
  }
}
function classify_float(x) {
  if (isFinite(x)) {
    if (Math.abs(x) >= 22250738585072014e-324) {
      return (
        /* FP_normal */
        0
      );
    } else if (x !== 0) {
      return (
        /* FP_subnormal */
        1
      );
    } else {
      return (
        /* FP_zero */
        2
      );
    }
  } else if (isNaN(x)) {
    return (
      /* FP_nan */
      4
    );
  } else {
    return (
      /* FP_infinite */
      3
    );
  }
}
function string_of_bool(b) {
  if (b) {
    return "true";
  } else {
    return "false";
  }
}
function int_of_string_opt(s) {
  try {
    return caml_int_of_string(s);
  } catch (raw_exn) {
    const exn = internalToOCamlException(raw_exn);
    if (exn.MEL_EXN_ID === Failure) {
      return;
    }
    throw exn;
  }
}
var Match_failure = "Match_failure";
var Assert_failure = "Assert_failure";
var Out_of_memory = "Out_of_memory";
var Stack_overflow = "Stack_overflow";
var Undefined_recursive_module = "Undefined_recursive_module";

// node_modules/melange/sys.js
var executable_name = caml_sys_executable_name();
var os_type2 = os_type();
var unix = os_type() === "Unix";
var win32 = os_type() === "Win32";
var max_string_length = 2147483647;
var max_array_length = 2147483647;

// node_modules/melange/obj.js
var max_ephe_length = max_array_length - 2 | 0;

// node_modules/melange/camlinternalAtomic.js
function make2(v) {
  return {
    v
  };
}
function get3(r) {
  return r.v;
}

// node_modules/melange/atomic.js
var make3 = make2;
var get4 = get3;

// node_modules/melange/array.js
function blit2(a1, ofs1, a2, ofs2, len) {
  if (len < 0 || ofs1 < 0 || ofs1 > (a1.length - len | 0) || ofs2 < 0 || ofs2 > (a2.length - len | 0)) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "Array.blit"
    });
  }
  blit(a1, ofs1, a2, ofs2, len);
}
function to_list(a) {
  let _i = a.length - 1 | 0;
  let _res = (
    /* [] */
    0
  );
  while (true) {
    const res = _res;
    const i = _i;
    if (i < 0) {
      return res;
    }
    _res = {
      hd: a[i],
      tl: res
    };
    _i = i - 1 | 0;
    continue;
  }
  ;
}

// node_modules/solid-ml-browser/dom.js
var $$document = document;
function add_class(element, cls) {
  element.classList.add(cls);
}
function get_pathname(param) {
  return window.location.pathname;
}
function push_state(url) {
  return window.history.pushState(null, "", url);
}
function on_popstate(handler) {
  return window.addEventListener("popstate", handler);
}
function query_selector_all(doc, selector) {
  return to_list(doc.querySelectorAll(selector));
}
function get_element_by_id(prim0, prim1) {
  return nullable_to_opt(prim0.getElementById(prim1));
}
function query_selector(prim0, prim1) {
  return nullable_to_opt(prim0.querySelector(prim1));
}
function get_attribute(prim0, prim1) {
  return nullable_to_opt(prim0.getAttribute(prim1));
}
function set_inner_html(prim0, prim1) {
  prim0.innerHTML = prim1;
}
function add_event_listener(prim0, prim1, prim2) {
  prim0.addEventListener(prim1, prim2);
}
function prevent_default(prim) {
  prim.preventDefault();
}
function log(prim) {
  console.log(prim);
}

// node_modules/solid-ml-internal/types.js
function create_runtime(param) {
  return {
    listener: void 0,
    owner: void 0,
    updates: (
      /* [] */
      0
    ),
    effects: (
      /* [] */
      0
    ),
    exec_count: 0,
    in_update: false
  };
}
function empty_computation(param) {
  return {
    fn: void 0,
    state: (
      /* Clean */
      0
    ),
    sources: [],
    source_slots: [],
    source_kinds: [],
    sources_len: 0,
    value: void 0,
    updated_at: 0,
    pure: false,
    user: false,
    owned: (
      /* [] */
      0
    ),
    cleanups: (
      /* [] */
      0
    ),
    owner: void 0,
    context: (
      /* [] */
      0
    ),
    child_owners: (
      /* [] */
      0
    ),
    memo_observers: void 0,
    memo_observer_slots: void 0,
    memo_observers_len: 0,
    memo_comparator: void 0
  };
}

// node_modules/melange/list.js
function length(l) {
  let _len = 0;
  let _param = l;
  while (true) {
    const param = _param;
    const len = _len;
    if (!param) {
      return len;
    }
    _param = param.tl;
    _len = len + 1 | 0;
    continue;
  }
  ;
}
function rev_append(_l1, _l2) {
  while (true) {
    const l2 = _l2;
    const l1 = _l1;
    if (!l1) {
      return l2;
    }
    _l2 = {
      hd: l1.hd,
      tl: l2
    };
    _l1 = l1.tl;
    continue;
  }
  ;
}
function rev(l) {
  return rev_append(
    l,
    /* [] */
    0
  );
}
function map_dps(_dst, _offset, f, _param) {
  while (true) {
    const dst = _dst;
    const offset = _offset;
    const param = _param;
    if (!param) {
      dst[offset] = /* [] */
      0;
      return;
    }
    const match = param.tl;
    const a1 = param.hd;
    if (match) {
      const r1 = _1(f, a1);
      const r2 = _1(f, match.hd);
      const block = {
        hd: r2,
        tl: 24029
      };
      dst[offset] = {
        hd: r1,
        tl: block
      };
      _param = match.tl;
      _offset = "tl";
      _dst = block;
      continue;
    }
    const r1$1 = _1(f, a1);
    dst[offset] = {
      hd: r1$1,
      tl: (
        /* [] */
        0
      )
    };
    return;
  }
  ;
}
function map(f, param) {
  if (!param) {
    return (
      /* [] */
      0
    );
  }
  const match = param.tl;
  const a1 = param.hd;
  if (match) {
    const r1 = _1(f, a1);
    const r2 = _1(f, match.hd);
    const block = {
      hd: r2,
      tl: 24029
    };
    return {
      hd: r1,
      tl: (map_dps(block, "tl", f, match.tl), block)
    };
  }
  const r1$1 = _1(f, a1);
  return {
    hd: r1$1,
    tl: (
      /* [] */
      0
    )
  };
}
function iter(f, _param) {
  while (true) {
    const param = _param;
    if (!param) {
      return;
    }
    _1(f, param.hd);
    _param = param.tl;
    continue;
  }
  ;
}
function assoc_opt(x, _param) {
  while (true) {
    const param = _param;
    if (!param) {
      return;
    }
    const match = param.hd;
    if (caml_equal(match[0], x)) {
      return some(match[1]);
    }
    _param = param.tl;
    continue;
  }
  ;
}
function find_all(p, _param) {
  while (true) {
    const param = _param;
    if (!param) {
      return (
        /* [] */
        0
      );
    }
    const l = param.tl;
    const x = param.hd;
    if (_1(p, x)) {
      const block = {
        hd: x,
        tl: 24029
      };
      find_all_dps(block, "tl", p, l);
      return block;
    }
    _param = l;
    continue;
  }
  ;
}
function find_all_dps(_dst, _offset, p, _param) {
  while (true) {
    const dst = _dst;
    const offset = _offset;
    const param = _param;
    if (!param) {
      dst[offset] = /* [] */
      0;
      return;
    }
    const l = param.tl;
    const x = param.hd;
    if (_1(p, x)) {
      const block = {
        hd: x,
        tl: 24029
      };
      dst[offset] = block;
      _param = l;
      _offset = "tl";
      _dst = block;
      continue;
    }
    _param = l;
    continue;
  }
  ;
}
function partition(p, l) {
  let _yes = (
    /* [] */
    0
  );
  let _no = (
    /* [] */
    0
  );
  let _param = l;
  while (true) {
    const param = _param;
    const no = _no;
    const yes = _yes;
    if (!param) {
      return [
        rev_append(
          yes,
          /* [] */
          0
        ),
        rev_append(
          no,
          /* [] */
          0
        )
      ];
    }
    const l$1 = param.tl;
    const x = param.hd;
    if (_1(p, x)) {
      _param = l$1;
      _yes = {
        hd: x,
        tl: yes
      };
      continue;
    }
    _param = l$1;
    _no = {
      hd: x,
      tl: no
    };
    continue;
  }
  ;
}
var filter = find_all;

// node_modules/solid-ml-internal/reactive_functor.js
function Make(B) {
  const get_runtime2 = function(param) {
    const rt = _1(B.get_runtime, void 0);
    if (rt !== void 0) {
      return rt;
    } else {
      return failwith("No reactive runtime active. Use Runtime.run or create_root.");
    }
  };
  const get_runtime_opt = function(param) {
    return _1(B.get_runtime, void 0);
  };
  const set_runtime2 = function(rt) {
    _1(B.set_runtime, rt);
  };
  const ensure_capacity = function(arr, len, needed, $$default) {
    const current_len = arr.length;
    if (current_len >= needed) {
      return arr;
    }
    const new_len = caml_int_max(needed, current_len << 1);
    const new_arr = make(new_len, $$default);
    blit2(arr, 0, new_arr, 0, len);
    return new_arr;
  };
  const ensure_capacity_kinds = function(arr, len, needed) {
    const current_len = arr.length;
    if (current_len >= needed) {
      return arr;
    }
    const new_len = caml_int_max(needed, current_len << 1);
    const new_arr = make(
      new_len,
      /* Signal_source */
      0
    );
    blit2(arr, 0, new_arr, 0, len);
    return new_arr;
  };
  const clean_node_ref = {
    contents: (function(param) {
    })
  };
  const dispose_owner_ref = {
    contents: (function(param) {
    })
  };
  const read_signal = function(signal) {
    const rt = get_runtime2();
    const listener = rt.listener;
    if (listener !== void 0) {
      const s_slot = signal.observers_len;
      if (listener.sources_len === 0) {
        listener.sources = make(4, signal);
        listener.source_slots = make(4, s_slot);
        listener.source_kinds = make(
          4,
          /* Signal_source */
          0
        );
        listener.sources_len = 1;
      } else {
        listener.sources = ensure_capacity(listener.sources, listener.sources_len, listener.sources_len + 1 | 0, signal);
        listener.source_slots = ensure_capacity(listener.source_slots, listener.sources_len, listener.sources_len + 1 | 0, 0);
        listener.source_kinds = ensure_capacity_kinds(listener.source_kinds, listener.sources_len, listener.sources_len + 1 | 0);
        set(listener.sources, listener.sources_len, signal);
        set(listener.source_slots, listener.sources_len, s_slot);
        set(
          listener.source_kinds,
          listener.sources_len,
          /* Signal_source */
          0
        );
        listener.sources_len = listener.sources_len + 1 | 0;
      }
      if (signal.observers_len === 0) {
        signal.observers = make(4, listener);
        signal.observer_slots = make(4, listener.sources_len - 1 | 0);
        signal.observers_len = 1;
      } else {
        signal.observers = ensure_capacity(signal.observers, signal.observers_len, signal.observers_len + 1 | 0, empty_computation());
        signal.observer_slots = ensure_capacity(signal.observer_slots, signal.observers_len, signal.observers_len + 1 | 0, 0);
        set(signal.observers, signal.observers_len, listener);
        set(signal.observer_slots, signal.observers_len, listener.sources_len - 1 | 0);
        signal.observers_len = signal.observers_len + 1 | 0;
      }
    }
    return signal.value;
  };
  const read_memo = function(memo) {
    const rt = get_runtime2();
    const listener = rt.listener;
    if (listener !== void 0 && memo.memo_observers !== void 0) {
      const m_slot = memo.memo_observers_len;
      if (listener.sources_len === 0) {
        listener.sources = make(4, memo);
        listener.source_slots = make(4, m_slot);
        listener.source_kinds = make(
          4,
          /* Memo_source */
          1
        );
        listener.sources_len = 1;
      } else {
        listener.sources = ensure_capacity(listener.sources, listener.sources_len, listener.sources_len + 1 | 0, memo);
        listener.source_slots = ensure_capacity(listener.source_slots, listener.sources_len, listener.sources_len + 1 | 0, 0);
        listener.source_kinds = ensure_capacity_kinds(listener.source_kinds, listener.sources_len, listener.sources_len + 1 | 0);
        set(listener.sources, listener.sources_len, memo);
        set(listener.source_slots, listener.sources_len, m_slot);
        set(
          listener.source_kinds,
          listener.sources_len,
          /* Memo_source */
          1
        );
        listener.sources_len = listener.sources_len + 1 | 0;
      }
      const o = memo.memo_observers;
      const observers = o !== void 0 ? o : [];
      const s = memo.memo_observer_slots;
      const slots = s !== void 0 ? s : [];
      if (memo.memo_observers_len === 0) {
        memo.memo_observers = make(4, listener);
        memo.memo_observer_slots = make(4, listener.sources_len - 1 | 0);
        memo.memo_observers_len = 1;
      } else {
        const new_observers = ensure_capacity(observers, memo.memo_observers_len, memo.memo_observers_len + 1 | 0, empty_computation());
        const new_slots = ensure_capacity(slots, memo.memo_observers_len, memo.memo_observers_len + 1 | 0, 0);
        set(new_observers, memo.memo_observers_len, listener);
        set(new_slots, memo.memo_observers_len, listener.sources_len - 1 | 0);
        memo.memo_observers = new_observers;
        memo.memo_observer_slots = new_slots;
        memo.memo_observers_len = memo.memo_observers_len + 1 | 0;
      }
    }
    return memo.value;
  };
  const mark_downstream = function(node) {
    const rt = get_runtime2();
    const observers = node.memo_observers;
    if (observers === void 0) {
      return;
    }
    for (let i = 0, i_finish = node.memo_observers_len; i < i_finish; ++i) {
      const o = get2(observers, i);
      if (o.state === /* Clean */
      0) {
        o.state = /* Pending */
        2;
        if (o.pure) {
          rt.updates = {
            hd: o,
            tl: rt.updates
          };
        } else {
          rt.effects = {
            hd: o,
            tl: rt.effects
          };
        }
        if (o.memo_observers !== void 0) {
          mark_downstream(o);
        }
      }
    }
  };
  const run_updates_ref = {
    contents: (function(f, param) {
      _1(f, void 0);
    })
  };
  const write_signal = function(signal, value) {
    const cmp = signal.comparator;
    const should_update = cmp !== void 0 ? !_2(cmp, signal.value, value) : caml_notequal(signal.value, value);
    if (!should_update) {
      return;
    }
    signal.value = value;
    if (signal.observers_len <= 0) {
      return;
    }
    const rt = get_runtime2();
    _2(run_updates_ref.contents, (function(param) {
      for (let i = 0, i_finish = signal.observers_len; i < i_finish; ++i) {
        const o = get2(signal.observers, i);
        if (o.state === /* Clean */
        0) {
          if (o.pure) {
            rt.updates = {
              hd: o,
              tl: rt.updates
            };
          } else {
            rt.effects = {
              hd: o,
              tl: rt.effects
            };
          }
          if (o.memo_observers !== void 0) {
            mark_downstream(o);
          }
        }
        o.state = /* Stale */
        1;
      }
    }), false);
  };
  const clean_node = function(node) {
    for (let i = 0, i_finish = node.sources_len; i < i_finish; ++i) {
      const source_obj = get2(node.sources, i);
      const slot = get2(node.source_slots, i);
      const kind = get2(node.source_kinds, i);
      if (kind === /* Signal_source */
      0) {
        if (source_obj.observers_len > 0) {
          const last_idx = source_obj.observers_len - 1 | 0;
          if (slot < last_idx) {
            const last_observer = get2(source_obj.observers, last_idx);
            const last_slot = get2(source_obj.observer_slots, last_idx);
            set(source_obj.observers, slot, last_observer);
            set(source_obj.observer_slots, slot, last_slot);
            set(last_observer.source_slots, last_slot, slot);
          }
          source_obj.observers_len = source_obj.observers_len - 1 | 0;
        }
      } else {
        const observers = source_obj.memo_observers;
        if (observers !== void 0 && source_obj.memo_observers_len > 0) {
          const last_idx$1 = source_obj.memo_observers_len - 1 | 0;
          if (slot < last_idx$1) {
            const last_observer$1 = get2(observers, last_idx$1);
            const s = source_obj.memo_observer_slots;
            const slots = s !== void 0 ? s : failwith("memo_observer_slots should exist");
            const last_slot$1 = get2(slots, last_idx$1);
            set(observers, slot, last_observer$1);
            set(slots, slot, last_slot$1);
            set(last_observer$1.source_slots, last_slot$1, slot);
          }
          source_obj.memo_observers_len = source_obj.memo_observers_len - 1 | 0;
        }
      }
    }
    node.sources_len = 0;
    iter((function(child_owner) {
      _1(dispose_owner_ref.contents, child_owner);
    }), rev(node.child_owners));
    node.child_owners = /* [] */
    0;
    iter((function(child) {
      _1(clean_node_ref.contents, child);
    }), node.owned);
    node.owned = /* [] */
    0;
    iter((function(cleanup) {
      _1(cleanup, void 0);
    }), rev(node.cleanups));
    node.cleanups = /* [] */
    0;
    node.state = /* Clean */
    0;
  };
  clean_node_ref.contents = clean_node;
  const run_computation = function(node) {
    const rt = get_runtime2();
    const fn = node.fn;
    if (fn === void 0) {
      return;
    }
    const prev_listener = rt.listener;
    const prev_owner = rt.owner;
    const temp_owner = {
      owned: (
        /* [] */
        0
      ),
      cleanups: (
        /* [] */
        0
      ),
      owner: node.owner,
      context: node.context,
      child_owners: (
        /* [] */
        0
      )
    };
    rt.listener = node;
    rt.owner = temp_owner;
    try {
      const next_value = _1(fn, node.value);
      node.value = next_value;
      node.updated_at = rt.exec_count;
      node.owned = temp_owner.owned;
      node.cleanups = temp_owner.cleanups;
      node.child_owners = temp_owner.child_owners;
    } catch (exn) {
      node.owned = temp_owner.owned;
      node.cleanups = temp_owner.cleanups;
      node.child_owners = temp_owner.child_owners;
      rt.listener = prev_listener;
      rt.owner = prev_owner;
      throw exn;
    }
    rt.listener = prev_listener;
    rt.owner = prev_owner;
  };
  const update_computation = function(node) {
    if (node.fn === void 0) {
      return;
    } else {
      clean_node(node);
      return run_computation(node);
    }
  };
  const look_upstream = function(node) {
    node.state = /* Clean */
    0;
  };
  const run_top = function(node) {
    if (node.state === /* Clean */
    0) {
      return;
    } else if (node.state === /* Pending */
    2) {
      node.state = /* Clean */
      0;
      return;
    } else {
      return update_computation(node);
    }
  };
  const complete_updates = function(param) {
    const rt = get_runtime2();
    let _param;
    while (true) {
      if (!(caml_notequal(
        rt.updates,
        /* [] */
        0
      ) || caml_notequal(
        rt.effects,
        /* [] */
        0
      ))) {
        return;
      }
      while (caml_notequal(
        rt.updates,
        /* [] */
        0
      )) {
        const updates = rt.updates;
        rt.updates = /* [] */
        0;
        iter((function(node) {
          try {
            return run_top(node);
          } catch (raw_exn) {
            const exn = internalToOCamlException(raw_exn);
            return _2(B.handle_error, exn, "memo");
          }
        }), rev(updates));
      }
      ;
      const effects = rt.effects;
      rt.effects = /* [] */
      0;
      const match = partition((function(e) {
        return !e.user;
      }), effects);
      iter((function(node) {
        try {
          return run_top(node);
        } catch (raw_exn) {
          const exn = internalToOCamlException(raw_exn);
          return _2(B.handle_error, exn, "effect");
        }
      }), rev(match[0]));
      iter((function(node) {
        try {
          return run_top(node);
        } catch (raw_exn) {
          const exn = internalToOCamlException(raw_exn);
          return _2(B.handle_error, exn, "effect");
        }
      }), rev(match[1]));
      _param = void 0;
      continue;
    }
    ;
  };
  const run_updates = function(fn, init3) {
    const rt = get_runtime2();
    if (rt.in_update) {
      return _1(fn, void 0);
    }
    rt.in_update = true;
    rt.exec_count = rt.exec_count + 1 | 0;
    if (!init3) {
      rt.updates = /* [] */
      0;
      rt.effects = /* [] */
      0;
    }
    let result;
    try {
      const res = _1(fn, void 0);
      complete_updates();
      result = res;
    } catch (exn) {
      rt.in_update = false;
      rt.updates = /* [] */
      0;
      rt.effects = /* [] */
      0;
      throw exn;
    }
    rt.in_update = false;
    return result;
  };
  run_updates_ref.contents = run_updates;
  const create_computation = function(fn, init3, pure, initial_state) {
    const rt = get_runtime2();
    const o = rt.owner;
    const comp = {
      fn,
      state: initial_state,
      sources: [],
      source_slots: [],
      source_kinds: [],
      sources_len: 0,
      value: init3,
      updated_at: 0,
      pure,
      user: false,
      owned: (
        /* [] */
        0
      ),
      cleanups: (
        /* [] */
        0
      ),
      owner: rt.owner,
      context: o !== void 0 ? o.context : (
        /* [] */
        0
      ),
      child_owners: (
        /* [] */
        0
      ),
      memo_observers: void 0,
      memo_observer_slots: void 0,
      memo_observers_len: 0,
      memo_comparator: void 0
    };
    const owner = rt.owner;
    if (owner !== void 0) {
      owner.owned = {
        hd: comp,
        tl: owner.owned
      };
    }
    return comp;
  };
  const run = function(fn) {
    const rt = create_runtime();
    const prev = _1(B.get_runtime, void 0);
    _1(B.set_runtime, rt);
    let result;
    try {
      result = _1(fn, void 0);
    } catch (exn) {
      _1(B.set_runtime, prev);
      throw exn;
    }
    _1(B.set_runtime, prev);
    return result;
  };
  const dispose_owner = function(owner) {
    iter(dispose_owner, rev(owner.child_owners));
    owner.child_owners = /* [] */
    0;
    iter((function(comp) {
      comp.fn = void 0;
      clean_node(comp);
    }), owner.owned);
    owner.owned = /* [] */
    0;
    iter((function(cleanup) {
      _1(cleanup, void 0);
    }), rev(owner.cleanups));
    owner.cleanups = /* [] */
    0;
    const parent = owner.owner;
    if (parent !== void 0) {
      parent.child_owners = filter((function(c) {
        return c !== owner;
      }), parent.child_owners);
      return;
    }
  };
  dispose_owner_ref.contents = dispose_owner;
  const create_root2 = function(fn) {
    const rt = get_runtime2();
    const prev_owner = rt.owner;
    const root_owner = {
      owned: (
        /* [] */
        0
      ),
      cleanups: (
        /* [] */
        0
      ),
      owner: prev_owner,
      context: prev_owner !== void 0 ? prev_owner.context : (
        /* [] */
        0
      ),
      child_owners: (
        /* [] */
        0
      )
    };
    if (prev_owner !== void 0) {
      prev_owner.child_owners = {
        hd: root_owner,
        tl: prev_owner.child_owners
      };
    }
    rt.owner = root_owner;
    const dispose = function(param) {
      dispose_owner(root_owner);
    };
    try {
      const res = _1(fn, dispose);
      rt.owner = prev_owner;
      return res;
    } catch (exn) {
      rt.owner = prev_owner;
      throw exn;
    }
  };
  const on_cleanup2 = function(fn) {
    const rt = get_runtime2();
    const owner = rt.owner;
    if (owner !== void 0) {
      owner.cleanups = {
        hd: fn,
        tl: owner.cleanups
      };
      return;
    }
  };
  const get_owner2 = function(param) {
    return get_runtime2().owner;
  };
  const untrack2 = function(fn) {
    const rt = get_runtime2();
    const prev = rt.listener;
    rt.listener = void 0;
    let result;
    try {
      result = _1(fn, void 0);
    } catch (exn) {
      rt.listener = prev;
      throw exn;
    }
    rt.listener = prev;
    return result;
  };
  const create_signal_internal = function(comparator, initial) {
    return {
      value: initial,
      observers: [],
      observer_slots: [],
      observers_len: 0,
      comparator
    };
  };
  const create_typed_signal = function(equals, initial) {
    const comparator = equals !== void 0 ? __2(equals) : void 0;
    return create_signal_internal(comparator, initial);
  };
  const read_typed_signal = read_signal;
  const write_typed_signal = write_signal;
  const peek_typed_signal = function(s) {
    return s.value;
  };
  const create_typed_memo = function(equalsOpt, fn) {
    const equals = equalsOpt !== void 0 ? equalsOpt : caml_equal;
    const memo_ref = {
      contents: void 0
    };
    const comp = create_computation(
      (function(_prev) {
        const new_val = _1(fn, void 0);
        const m2 = memo_ref.contents;
        if (m2 !== void 0) {
          if (m2.has_cached && !_2(m2.equals, m2.cached, new_val)) {
            m2.cached = new_val;
            const rt = get_runtime2();
            const observers = m2.comp.memo_observers;
            if (observers !== void 0) {
              for (let i = 0, i_finish = m2.comp.memo_observers_len; i < i_finish; ++i) {
                const o = get2(observers, i);
                if (o.state === /* Clean */
                0) {
                  o.state = /* Stale */
                  1;
                  if (o.pure) {
                    rt.updates = {
                      hd: o,
                      tl: rt.updates
                    };
                  } else {
                    rt.effects = {
                      hd: o,
                      tl: rt.effects
                    };
                  }
                } else if (o.state === /* Pending */
                2) {
                  o.state = /* Stale */
                  1;
                }
              }
            }
          } else {
            m2.cached = new_val;
            m2.has_cached = true;
          }
        }
        return new_val;
      }),
      void 0,
      true,
      /* Stale */
      1
    );
    comp.memo_observers = [];
    comp.memo_observer_slots = [];
    const m = {
      comp,
      cached: void 0,
      has_cached: false,
      equals
    };
    memo_ref.contents = m;
    update_computation(comp);
    return m;
  };
  const read_typed_memo = function(m) {
    const comp = m.comp;
    if (comp.state === /* Stale */
    1) {
      clean_node(comp);
      run_computation(comp);
      comp.state = /* Clean */
      0;
    } else if (comp.state === /* Pending */
    2) {
      comp.state = /* Clean */
      0;
      if (comp.state === /* Stale */
      1) {
        clean_node(comp);
        run_computation(comp);
        comp.state = /* Clean */
        0;
      }
    }
    const rt = get_runtime2();
    const listener = rt.listener;
    if (listener !== void 0) {
      const s_slot = comp.memo_observers_len;
      if (listener.sources_len === 0) {
        listener.sources = make(4, comp);
        listener.source_slots = make(4, s_slot);
        listener.source_kinds = make(
          4,
          /* Memo_source */
          1
        );
        listener.sources_len = 1;
      } else {
        listener.sources = ensure_capacity(listener.sources, listener.sources_len, listener.sources_len + 1 | 0, comp);
        listener.source_slots = ensure_capacity(listener.source_slots, listener.sources_len, listener.sources_len + 1 | 0, 0);
        listener.source_kinds = ensure_capacity_kinds(listener.source_kinds, listener.sources_len, listener.sources_len + 1 | 0);
        set(listener.sources, listener.sources_len, comp);
        set(listener.source_slots, listener.sources_len, s_slot);
        set(
          listener.source_kinds,
          listener.sources_len,
          /* Memo_source */
          1
        );
        listener.sources_len = listener.sources_len + 1 | 0;
      }
      const o = comp.memo_observers;
      const observers = o !== void 0 ? o : [];
      const s = comp.memo_observer_slots;
      const slots = s !== void 0 ? s : [];
      if (comp.memo_observers_len === 0) {
        comp.memo_observers = make(4, listener);
        comp.memo_observer_slots = make(4, listener.sources_len - 1 | 0);
        comp.memo_observers_len = 1;
      } else {
        const new_observers = ensure_capacity(observers, comp.memo_observers_len, comp.memo_observers_len + 1 | 0, empty_computation());
        const new_slots = ensure_capacity(slots, comp.memo_observers_len, comp.memo_observers_len + 1 | 0, 0);
        set(new_observers, comp.memo_observers_len, listener);
        set(new_slots, comp.memo_observers_len, listener.sources_len - 1 | 0);
        comp.memo_observers = new_observers;
        comp.memo_observer_slots = new_slots;
        comp.memo_observers_len = comp.memo_observers_len + 1 | 0;
      }
    }
    return m.cached;
  };
  const peek_typed_memo = function(m) {
    return m.cached;
  };
  const create_effect2 = function(fn) {
    const comp = create_computation(
      (function(param) {
        _1(fn, void 0);
      }),
      void 0,
      false,
      /* Stale */
      1
    );
    comp.user = true;
    const rt = get_runtime2();
    if (rt.in_update) {
      rt.effects = {
        hd: comp,
        tl: rt.effects
      };
      return;
    } else {
      return run_updates((function(param) {
        run_top(comp);
      }), true);
    }
  };
  const create_effect_with_cleanup2 = function(fn) {
    const cleanup_ref = {
      contents: (function(param) {
      })
    };
    const comp = create_computation(
      (function(param) {
        _1(cleanup_ref.contents, void 0);
        const new_cleanup = _1(fn, void 0);
        cleanup_ref.contents = new_cleanup;
      }),
      void 0,
      false,
      /* Stale */
      1
    );
    comp.user = true;
    on_cleanup2(function(param) {
      _1(cleanup_ref.contents, void 0);
    });
    const rt = get_runtime2();
    if (rt.in_update) {
      rt.effects = {
        hd: comp,
        tl: rt.effects
      };
      return;
    } else {
      return run_updates((function(param) {
        run_top(comp);
      }), true);
    }
  };
  const next_context_id = {
    contents: 0
  };
  const create_context2 = function($$default) {
    const id = next_context_id.contents;
    next_context_id.contents = next_context_id.contents + 1 | 0;
    return {
      ctx_id: id,
      ctx_default: $$default
    };
  };
  const find_context_in_owner = function(ctx_id, _owner) {
    while (true) {
      const owner = _owner;
      const v = assoc_opt(ctx_id, owner.context);
      if (v !== void 0) {
        return some(valFromOption(v));
      }
      const parent = owner.owner;
      if (parent === void 0) {
        return;
      }
      _owner = parent;
      continue;
    }
    ;
  };
  const use_context2 = function(ctx) {
    const rt = _1(B.get_runtime, void 0);
    if (rt === void 0) {
      return ctx.ctx_default;
    }
    const owner = rt.owner;
    if (owner === void 0) {
      return ctx.ctx_default;
    }
    const v = find_context_in_owner(ctx.ctx_id, owner);
    if (v !== void 0) {
      return valFromOption(v);
    } else {
      return ctx.ctx_default;
    }
  };
  const provide_context2 = function(ctx, value, fn) {
    const rt = _1(B.get_runtime, void 0);
    if (rt === void 0) {
      return run(function(param) {
        return create_root2(function(_dispose) {
          const rt2 = get_runtime2();
          const owner2 = rt2.owner;
          if (owner2 !== void 0) {
            owner2.context = {
              hd: [
                ctx.ctx_id,
                value
              ],
              tl: owner2.context
            };
            return _1(fn, void 0);
          } else {
            return _1(fn, void 0);
          }
        });
      });
    }
    const owner = rt.owner;
    if (owner === void 0) {
      return create_root2(function(_dispose) {
        const rt2 = get_runtime2();
        const owner2 = rt2.owner;
        if (owner2 !== void 0) {
          owner2.context = {
            hd: [
              ctx.ctx_id,
              value
            ],
            tl: owner2.context
          };
          return _1(fn, void 0);
        } else {
          return _1(fn, void 0);
        }
      });
    }
    const prev = owner.context;
    owner.context = {
      hd: [
        ctx.ctx_id,
        value
      ],
      tl: prev
    };
    let result;
    try {
      result = _1(fn, void 0);
    } catch (e) {
      owner.context = prev;
      throw e;
    }
    owner.context = prev;
    return result;
  };
  return {
    get_runtime: get_runtime2,
    get_runtime_opt,
    set_runtime: set_runtime2,
    ensure_capacity,
    ensure_capacity_kinds,
    clean_node_ref,
    dispose_owner_ref,
    read_signal,
    read_memo,
    mark_downstream,
    run_updates_ref,
    write_signal,
    clean_node,
    run_computation,
    update_computation,
    look_upstream,
    run_top,
    complete_updates,
    run_updates,
    create_computation,
    run,
    dispose_owner,
    create_root: create_root2,
    on_cleanup: on_cleanup2,
    get_owner: get_owner2,
    untrack: untrack2,
    create_signal_internal,
    create_typed_signal,
    read_typed_signal,
    write_typed_signal,
    peek_typed_signal,
    create_typed_memo,
    read_typed_memo,
    peek_typed_memo,
    create_effect: create_effect2,
    create_effect_with_cleanup: create_effect_with_cleanup2,
    next_context_id,
    create_context: create_context2,
    find_context_in_owner,
    use_context: use_context2,
    provide_context: provide_context2
  };
}

// node_modules/melange/char.js
function escaped(c) {
  let exit2 = 0;
  if (c >= 40) {
    if (c === 92) {
      return "\\\\";
    }
    exit2 = c >= 127 ? 1 : 2;
  } else if (c >= 32) {
    if (c >= 39) {
      return "\\'";
    }
    exit2 = 2;
  } else if (c >= 14) {
    exit2 = 1;
  } else {
    switch (c) {
      case 8:
        return "\\b";
      case 9:
        return "\\t";
      case 10:
        return "\\n";
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 11:
      case 12:
        exit2 = 1;
        break;
      case 13:
        return "\\r";
    }
  }
  switch (exit2) {
    case 1:
      const s = [
        0,
        0,
        0,
        0
      ];
      s[0] = /* '\\' */
      92;
      s[1] = 48 + (c / 100 | 0) | 0;
      s[2] = 48 + (c / 10 | 0) % 10 | 0;
      s[3] = 48 + c % 10 | 0;
      return bytes_to_string(s);
    case 2:
      const s$1 = [0];
      s$1[0] = c;
      return bytes_to_string(s$1);
  }
}
function uppercase_ascii(c) {
  if (c > 122 || c < 97) {
    return c;
  } else {
    return c - 32 | 0;
  }
}

// node_modules/melange/int.js
function max(x, y) {
  if (x >= y) {
    return x;
  } else {
    return y;
  }
}

// node_modules/melange/bytes.js
function make4(n, c) {
  const s = caml_create_bytes(n);
  caml_fill_bytes(s, 0, n, c);
  return s;
}
function sub3(s, ofs, len) {
  if (ofs < 0 || len < 0 || ofs > (s.length - len | 0)) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "String.sub / Bytes.sub"
    });
  }
  const r = caml_create_bytes(len);
  caml_blit_bytes(s, ofs, r, 0, len);
  return r;
}
function sub_string(b, ofs, len) {
  return bytes_to_string(sub3(b, ofs, len));
}
function blit3(s1, ofs1, s2, ofs2, len) {
  if (len < 0 || ofs1 < 0 || ofs1 > (s1.length - len | 0) || ofs2 < 0 || ofs2 > (s2.length - len | 0)) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "Bytes.blit"
    });
  }
  caml_blit_bytes(s1, ofs1, s2, ofs2, len);
}
function blit_string(s1, ofs1, s2, ofs2, len) {
  if (len < 0 || ofs1 < 0 || ofs1 > (s1.length - len | 0) || ofs2 < 0 || ofs2 > (s2.length - len | 0)) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "String.blit / Bytes.blit_string"
    });
  }
  caml_blit_string(s1, ofs1, s2, ofs2, len);
}
function unsafe_escape(s) {
  let n = 0;
  for (let i = 0, i_finish = s.length; i < i_finish; ++i) {
    const match = s[i];
    n = n + (match >= 32 ? match > 92 || match < 34 ? match >= 127 ? 4 : 1 : match > 91 || match < 35 ? 2 : 1 : match >= 11 ? match !== 13 ? 4 : 2 : match >= 8 ? 2 : 4) | 0;
  }
  if (n === s.length) {
    return s;
  }
  const s$p = caml_create_bytes(n);
  n = 0;
  for (let i$1 = 0, i_finish$1 = s.length; i$1 < i_finish$1; ++i$1) {
    const c = s[i$1];
    let exit2 = 0;
    if (c >= 35) {
      if (c !== 92) {
        if (c >= 127) {
          exit2 = 1;
        } else {
          s$p[n] = c;
        }
      } else {
        exit2 = 2;
      }
    } else if (c >= 32) {
      if (c >= 34) {
        exit2 = 2;
      } else {
        s$p[n] = c;
      }
    } else if (c >= 14) {
      exit2 = 1;
    } else {
      switch (c) {
        case 8:
          s$p[n] = /* '\\' */
          92;
          n = n + 1 | 0;
          s$p[n] = /* 'b' */
          98;
          break;
        case 9:
          s$p[n] = /* '\\' */
          92;
          n = n + 1 | 0;
          s$p[n] = /* 't' */
          116;
          break;
        case 10:
          s$p[n] = /* '\\' */
          92;
          n = n + 1 | 0;
          s$p[n] = /* 'n' */
          110;
          break;
        case 0:
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 11:
        case 12:
          exit2 = 1;
          break;
        case 13:
          s$p[n] = /* '\\' */
          92;
          n = n + 1 | 0;
          s$p[n] = /* 'r' */
          114;
          break;
      }
    }
    switch (exit2) {
      case 1:
        s$p[n] = /* '\\' */
        92;
        n = n + 1 | 0;
        s$p[n] = 48 + (c / 100 | 0) | 0;
        n = n + 1 | 0;
        s$p[n] = 48 + (c / 10 | 0) % 10 | 0;
        n = n + 1 | 0;
        s$p[n] = 48 + c % 10 | 0;
        break;
      case 2:
        s$p[n] = /* '\\' */
        92;
        n = n + 1 | 0;
        s$p[n] = c;
        break;
    }
    n = n + 1 | 0;
  }
  return s$p;
}
function map2(f, s) {
  const l = s.length;
  if (l === 0) {
    return s;
  }
  const r = caml_create_bytes(l);
  for (let i = 0; i < l; ++i) {
    r[i] = _1(f, s[i]);
  }
  return r;
}
function uppercase_ascii2(s) {
  return map2(uppercase_ascii, s);
}

// node_modules/melange/string.js
function sub4(s, ofs, len) {
  if (ofs === 0 && s.length === len) {
    return s;
  } else {
    return bytes_to_string(sub3(bytes_of_string(s), ofs, len));
  }
}
function ensure_ge(x, y) {
  if (x >= y) {
    return x;
  }
  throw new MelangeError("Invalid_argument", {
    MEL_EXN_ID: "Invalid_argument",
    _1: "String.concat"
  });
}
function sum_lengths(_acc, seplen, _param) {
  while (true) {
    const param = _param;
    const acc = _acc;
    if (!param) {
      return acc;
    }
    const hd = param.hd;
    if (!param.tl) {
      return hd.length + acc | 0;
    }
    _param = param.tl;
    _acc = ensure_ge((hd.length + seplen | 0) + acc | 0, acc);
    continue;
  }
  ;
}
function unsafe_blits(dst, _pos, sep, seplen, _param) {
  while (true) {
    const param = _param;
    const pos = _pos;
    if (!param) {
      return dst;
    }
    const hd = param.hd;
    if (param.tl) {
      caml_blit_string(hd, 0, dst, pos, hd.length);
      caml_blit_string(sep, 0, dst, pos + hd.length | 0, seplen);
      _param = param.tl;
      _pos = (pos + hd.length | 0) + seplen | 0;
      continue;
    }
    caml_blit_string(hd, 0, dst, pos, hd.length);
    return dst;
  }
  ;
}
function concat2(sep, l) {
  if (!l) {
    return "";
  }
  if (!l.tl) {
    return l.hd;
  }
  const seplen = sep.length;
  return bytes_to_string(unsafe_blits(caml_create_bytes(sum_lengths(0, seplen, l)), 0, sep, seplen, l));
}
function iter3(f, s) {
  for (let i = 0, i_finish = s.length; i < i_finish; ++i) {
    _1(f, s.charCodeAt(i));
  }
}
function escaped2(s) {
  const b = bytes_of_string(s);
  const b$p = unsafe_escape(b);
  if (b === b$p) {
    return s;
  } else {
    return bytes_to_string(b$p);
  }
}
var blit4 = blit_string;

// node_modules/melange/buffer.js
function create2(n) {
  const n$1 = n < 1 ? 1 : n;
  const n$2 = n$1 > max_string_length ? max_string_length : n$1;
  const s = caml_create_bytes(n$2);
  return {
    inner: {
      buffer: s,
      length: n$2
    },
    position: 0,
    initial_buffer: s
  };
}
function contents(b) {
  return sub_string(b.inner.buffer, 0, b.position);
}
function resize(b, more) {
  const old_pos = b.position;
  const old_len = b.inner.length;
  let new_len = old_len;
  while ((old_pos + more | 0) > new_len) {
    new_len = new_len << 1;
  }
  ;
  if (new_len > max_string_length) {
    if ((old_pos + more | 0) <= max_string_length) {
      new_len = max_string_length;
    } else {
      throw new MelangeError("Failure", {
        MEL_EXN_ID: "Failure",
        _1: "Buffer.add: cannot grow buffer"
      });
    }
  }
  const new_buffer = caml_create_bytes(new_len);
  blit3(b.inner.buffer, 0, new_buffer, 0, b.position);
  b.inner = {
    buffer: new_buffer,
    length: new_len
  };
}
function add_char(b, c) {
  const pos = b.position;
  const match = b.inner;
  if (pos >= match.length) {
    resize(b, 1);
    set2(b.inner.buffer, b.position, c);
  } else {
    match.buffer[pos] = c;
  }
  b.position = pos + 1 | 0;
}
function add_substring(b, s, offset, len) {
  if (offset < 0 || len < 0 || offset > (s.length - len | 0)) {
    throw new MelangeError("Invalid_argument", {
      MEL_EXN_ID: "Invalid_argument",
      _1: "Buffer.add_substring"
    });
  }
  const position = b.position;
  const match = b.inner;
  const new_position = position + len | 0;
  if (new_position > match.length) {
    resize(b, len);
    blit_string(s, offset, b.inner.buffer, b.position, len);
  } else {
    caml_blit_string(s, offset, match.buffer, position, len);
  }
  b.position = new_position;
}
function add_string(b, s) {
  add_substring(b, s, 0, s.length);
}

// node_modules/melange/camlinternalFormat.js
function default_float_precision(fconv) {
  const match = fconv[1];
  if (match === /* Float_F */
  5) {
    return 12;
  } else {
    return -6;
  }
}
function buffer_check_size(buf, overhead) {
  const len = buf.bytes.length;
  const min_len = buf.ind + overhead | 0;
  if (min_len <= len) {
    return;
  }
  const new_len = max(len << 1, min_len);
  const new_str = caml_create_bytes(new_len);
  blit3(buf.bytes, 0, new_str, 0, len);
  buf.bytes = new_str;
}
function buffer_add_char(buf, c) {
  buffer_check_size(buf, 1);
  set2(buf.bytes, buf.ind, c);
  buf.ind = buf.ind + 1 | 0;
}
function buffer_add_string(buf, s) {
  const str_len = s.length;
  buffer_check_size(buf, str_len);
  blit4(s, 0, buf.bytes, buf.ind, str_len);
  buf.ind = buf.ind + str_len | 0;
}
function buffer_contents(buf) {
  return sub_string(buf.bytes, 0, buf.ind);
}
function char_of_fconv(cFOpt, fconv) {
  const cF = cFOpt !== void 0 ? cFOpt : (
    /* 'F' */
    70
  );
  const match = fconv[1];
  switch (match) {
    case /* Float_f */
    0:
      return (
        /* 'f' */
        102
      );
    case /* Float_e */
    1:
      return (
        /* 'e' */
        101
      );
    case /* Float_E */
    2:
      return (
        /* 'E' */
        69
      );
    case /* Float_g */
    3:
      return (
        /* 'g' */
        103
      );
    case /* Float_G */
    4:
      return (
        /* 'G' */
        71
      );
    case /* Float_F */
    5:
      return cF;
    case /* Float_h */
    6:
      return (
        /* 'h' */
        104
      );
    case /* Float_H */
    7:
      return (
        /* 'H' */
        72
      );
    case /* Float_CF */
    8:
      return (
        /* 'F' */
        70
      );
  }
}
function bprint_fconv_flag(buf, fconv) {
  const match = fconv[0];
  switch (match) {
    case /* Float_flag_ */
    0:
      break;
    case /* Float_flag_p */
    1:
      buffer_add_char(
        buf,
        /* '+' */
        43
      );
      break;
    case /* Float_flag_s */
    2:
      buffer_add_char(
        buf,
        /* ' ' */
        32
      );
      break;
  }
  const match$1 = fconv[1];
  if (match$1 === /* Float_CF */
  8) {
    return buffer_add_char(
      buf,
      /* '#' */
      35
    );
  }
}
function string_of_formatting_lit(formatting_lit) {
  if (
    /* tag */
    typeof formatting_lit === "number" || typeof formatting_lit === "string"
  ) {
    switch (formatting_lit) {
      case /* Close_box */
      0:
        return "@]";
      case /* Close_tag */
      1:
        return "@}";
      case /* FFlush */
      2:
        return "@?";
      case /* Force_newline */
      3:
        return "@\n";
      case /* Flush_newline */
      4:
        return "@.";
      case /* Escaped_at */
      5:
        return "@@";
      case /* Escaped_percent */
      6:
        return "@%";
    }
  } else {
    switch (formatting_lit.TAG) {
      case /* Break */
      0:
      case /* Magic_size */
      1:
        return formatting_lit._0;
      case /* Scan_indic */
      2:
        return "@" + bytes_to_string(make4(1, formatting_lit._0));
    }
  }
}
function bprint_fmtty(buf, _fmtty) {
  while (true) {
    const fmtty = _fmtty;
    if (
      /* tag */
      typeof fmtty === "number" || typeof fmtty === "string"
    ) {
      return;
    }
    switch (fmtty.TAG) {
      case /* Char_ty */
      0:
        buffer_add_string(buf, "%c");
        _fmtty = fmtty._0;
        continue;
      case /* String_ty */
      1:
        buffer_add_string(buf, "%s");
        _fmtty = fmtty._0;
        continue;
      case /* Int_ty */
      2:
        buffer_add_string(buf, "%i");
        _fmtty = fmtty._0;
        continue;
      case /* Int32_ty */
      3:
        buffer_add_string(buf, "%li");
        _fmtty = fmtty._0;
        continue;
      case /* Nativeint_ty */
      4:
        buffer_add_string(buf, "%ni");
        _fmtty = fmtty._0;
        continue;
      case /* Int64_ty */
      5:
        buffer_add_string(buf, "%Li");
        _fmtty = fmtty._0;
        continue;
      case /* Float_ty */
      6:
        buffer_add_string(buf, "%f");
        _fmtty = fmtty._0;
        continue;
      case /* Bool_ty */
      7:
        buffer_add_string(buf, "%B");
        _fmtty = fmtty._0;
        continue;
      case /* Format_arg_ty */
      8:
        buffer_add_string(buf, "%{");
        bprint_fmtty(buf, fmtty._0);
        buffer_add_string(buf, "%}");
        _fmtty = fmtty._1;
        continue;
      case /* Format_subst_ty */
      9:
        buffer_add_string(buf, "%(");
        bprint_fmtty(buf, fmtty._0);
        buffer_add_string(buf, "%)");
        _fmtty = fmtty._2;
        continue;
      case /* Alpha_ty */
      10:
        buffer_add_string(buf, "%a");
        _fmtty = fmtty._0;
        continue;
      case /* Theta_ty */
      11:
        buffer_add_string(buf, "%t");
        _fmtty = fmtty._0;
        continue;
      case /* Any_ty */
      12:
        buffer_add_string(buf, "%?");
        _fmtty = fmtty._0;
        continue;
      case /* Reader_ty */
      13:
        buffer_add_string(buf, "%r");
        _fmtty = fmtty._0;
        continue;
      case /* Ignored_reader_ty */
      14:
        buffer_add_string(buf, "%_r");
        _fmtty = fmtty._0;
        continue;
    }
  }
  ;
}
function symm(rest) {
  if (
    /* tag */
    typeof rest === "number" || typeof rest === "string"
  ) {
    return (
      /* End_of_fmtty */
      0
    );
  }
  switch (rest.TAG) {
    case /* Char_ty */
    0:
      return {
        TAG: (
          /* Char_ty */
          0
        ),
        _0: symm(rest._0)
      };
    case /* String_ty */
    1:
      return {
        TAG: (
          /* String_ty */
          1
        ),
        _0: symm(rest._0)
      };
    case /* Int_ty */
    2:
      return {
        TAG: (
          /* Int_ty */
          2
        ),
        _0: symm(rest._0)
      };
    case /* Int32_ty */
    3:
      return {
        TAG: (
          /* Int32_ty */
          3
        ),
        _0: symm(rest._0)
      };
    case /* Nativeint_ty */
    4:
      return {
        TAG: (
          /* Nativeint_ty */
          4
        ),
        _0: symm(rest._0)
      };
    case /* Int64_ty */
    5:
      return {
        TAG: (
          /* Int64_ty */
          5
        ),
        _0: symm(rest._0)
      };
    case /* Float_ty */
    6:
      return {
        TAG: (
          /* Float_ty */
          6
        ),
        _0: symm(rest._0)
      };
    case /* Bool_ty */
    7:
      return {
        TAG: (
          /* Bool_ty */
          7
        ),
        _0: symm(rest._0)
      };
    case /* Format_arg_ty */
    8:
      return {
        TAG: (
          /* Format_arg_ty */
          8
        ),
        _0: rest._0,
        _1: symm(rest._1)
      };
    case /* Format_subst_ty */
    9:
      return {
        TAG: (
          /* Format_subst_ty */
          9
        ),
        _0: rest._1,
        _1: rest._0,
        _2: symm(rest._2)
      };
    case /* Alpha_ty */
    10:
      return {
        TAG: (
          /* Alpha_ty */
          10
        ),
        _0: symm(rest._0)
      };
    case /* Theta_ty */
    11:
      return {
        TAG: (
          /* Theta_ty */
          11
        ),
        _0: symm(rest._0)
      };
    case /* Any_ty */
    12:
      return {
        TAG: (
          /* Any_ty */
          12
        ),
        _0: symm(rest._0)
      };
    case /* Reader_ty */
    13:
      return {
        TAG: (
          /* Reader_ty */
          13
        ),
        _0: symm(rest._0)
      };
    case /* Ignored_reader_ty */
    14:
      return {
        TAG: (
          /* Ignored_reader_ty */
          14
        ),
        _0: symm(rest._0)
      };
  }
}
function fmtty_rel_det(rest) {
  if (
    /* tag */
    typeof rest === "number" || typeof rest === "string"
  ) {
    return [
      (function(param) {
        return (
          /* Refl */
          0
        );
      }),
      (function(param) {
        return (
          /* Refl */
          0
        );
      }),
      (function(param) {
        return (
          /* Refl */
          0
        );
      }),
      (function(param) {
        return (
          /* Refl */
          0
        );
      })
    ];
  }
  switch (rest.TAG) {
    case /* Char_ty */
    0:
      const match = fmtty_rel_det(rest._0);
      const af = match[1];
      const fa = match[0];
      return [
        (function(param) {
          _1(
            fa,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match[2],
        match[3]
      ];
    case /* String_ty */
    1:
      const match$1 = fmtty_rel_det(rest._0);
      const af$1 = match$1[1];
      const fa$1 = match$1[0];
      return [
        (function(param) {
          _1(
            fa$1,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$1,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$1[2],
        match$1[3]
      ];
    case /* Int_ty */
    2:
      const match$2 = fmtty_rel_det(rest._0);
      const af$2 = match$2[1];
      const fa$2 = match$2[0];
      return [
        (function(param) {
          _1(
            fa$2,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$2,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$2[2],
        match$2[3]
      ];
    case /* Int32_ty */
    3:
      const match$3 = fmtty_rel_det(rest._0);
      const af$3 = match$3[1];
      const fa$3 = match$3[0];
      return [
        (function(param) {
          _1(
            fa$3,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$3,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$3[2],
        match$3[3]
      ];
    case /* Nativeint_ty */
    4:
      const match$4 = fmtty_rel_det(rest._0);
      const af$4 = match$4[1];
      const fa$4 = match$4[0];
      return [
        (function(param) {
          _1(
            fa$4,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$4,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$4[2],
        match$4[3]
      ];
    case /* Int64_ty */
    5:
      const match$5 = fmtty_rel_det(rest._0);
      const af$5 = match$5[1];
      const fa$5 = match$5[0];
      return [
        (function(param) {
          _1(
            fa$5,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$5,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$5[2],
        match$5[3]
      ];
    case /* Float_ty */
    6:
      const match$6 = fmtty_rel_det(rest._0);
      const af$6 = match$6[1];
      const fa$6 = match$6[0];
      return [
        (function(param) {
          _1(
            fa$6,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$6,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$6[2],
        match$6[3]
      ];
    case /* Bool_ty */
    7:
      const match$7 = fmtty_rel_det(rest._0);
      const af$7 = match$7[1];
      const fa$7 = match$7[0];
      return [
        (function(param) {
          _1(
            fa$7,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$7,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$7[2],
        match$7[3]
      ];
    case /* Format_arg_ty */
    8:
      const match$8 = fmtty_rel_det(rest._1);
      const af$8 = match$8[1];
      const fa$8 = match$8[0];
      return [
        (function(param) {
          _1(
            fa$8,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$8,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$8[2],
        match$8[3]
      ];
    case /* Format_subst_ty */
    9:
      const match$9 = fmtty_rel_det(rest._2);
      const de = match$9[3];
      const ed = match$9[2];
      const af$9 = match$9[1];
      const fa$9 = match$9[0];
      const ty = trans(symm(rest._0), rest._1);
      const match$10 = fmtty_rel_det(ty);
      const jd = match$10[3];
      const dj = match$10[2];
      const ga = match$10[1];
      const ag = match$10[0];
      return [
        (function(param) {
          _1(
            fa$9,
            /* Refl */
            0
          );
          _1(
            ag,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            ga,
            /* Refl */
            0
          );
          _1(
            af$9,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            ed,
            /* Refl */
            0
          );
          _1(
            dj,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            jd,
            /* Refl */
            0
          );
          _1(
            de,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        })
      ];
    case /* Alpha_ty */
    10:
      const match$11 = fmtty_rel_det(rest._0);
      const af$10 = match$11[1];
      const fa$10 = match$11[0];
      return [
        (function(param) {
          _1(
            fa$10,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$10,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$11[2],
        match$11[3]
      ];
    case /* Theta_ty */
    11:
      const match$12 = fmtty_rel_det(rest._0);
      const af$11 = match$12[1];
      const fa$11 = match$12[0];
      return [
        (function(param) {
          _1(
            fa$11,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$11,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$12[2],
        match$12[3]
      ];
    case /* Any_ty */
    12:
      const match$13 = fmtty_rel_det(rest._0);
      const af$12 = match$13[1];
      const fa$12 = match$13[0];
      return [
        (function(param) {
          _1(
            fa$12,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$12,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        match$13[2],
        match$13[3]
      ];
    case /* Reader_ty */
    13:
      const match$14 = fmtty_rel_det(rest._0);
      const de$1 = match$14[3];
      const ed$1 = match$14[2];
      const af$13 = match$14[1];
      const fa$13 = match$14[0];
      return [
        (function(param) {
          _1(
            fa$13,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$13,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            ed$1,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            de$1,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        })
      ];
    case /* Ignored_reader_ty */
    14:
      const match$15 = fmtty_rel_det(rest._0);
      const de$2 = match$15[3];
      const ed$2 = match$15[2];
      const af$14 = match$15[1];
      const fa$14 = match$15[0];
      return [
        (function(param) {
          _1(
            fa$14,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            af$14,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            ed$2,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        }),
        (function(param) {
          _1(
            de$2,
            /* Refl */
            0
          );
          return (
            /* Refl */
            0
          );
        })
      ];
  }
}
function trans(ty1, ty2) {
  let exit2 = 0;
  if (
    /* tag */
    typeof ty1 === "number" || typeof ty1 === "string"
  ) {
    if (
      /* tag */
      typeof ty2 === "number" || typeof ty2 === "string"
    ) {
      return (
        /* End_of_fmtty */
        0
      );
    }
    switch (ty2.TAG) {
      case /* Format_arg_ty */
      8:
        exit2 = 6;
        break;
      case /* Format_subst_ty */
      9:
        exit2 = 7;
        break;
      case /* Alpha_ty */
      10:
        exit2 = 1;
        break;
      case /* Theta_ty */
      11:
        exit2 = 2;
        break;
      case /* Any_ty */
      12:
        exit2 = 3;
        break;
      case /* Reader_ty */
      13:
        exit2 = 4;
        break;
      case /* Ignored_reader_ty */
      14:
        exit2 = 5;
        break;
      default:
        throw new MelangeError("Assert_failure", {
          MEL_EXN_ID: "Assert_failure",
          _1: [
            "camlinternalFormat.cppo.ml",
            850,
            23
          ]
        });
    }
  } else {
    switch (ty1.TAG) {
      case /* Char_ty */
      0:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Char_ty */
            0:
              return {
                TAG: (
                  /* Char_ty */
                  0
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* String_ty */
      1:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* String_ty */
            1:
              return {
                TAG: (
                  /* String_ty */
                  1
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Int_ty */
      2:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Int_ty */
            2:
              return {
                TAG: (
                  /* Int_ty */
                  2
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Int32_ty */
      3:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Int32_ty */
            3:
              return {
                TAG: (
                  /* Int32_ty */
                  3
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Nativeint_ty */
      4:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Nativeint_ty */
            4:
              return {
                TAG: (
                  /* Nativeint_ty */
                  4
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Int64_ty */
      5:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Int64_ty */
            5:
              return {
                TAG: (
                  /* Int64_ty */
                  5
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Float_ty */
      6:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Float_ty */
            6:
              return {
                TAG: (
                  /* Float_ty */
                  6
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Bool_ty */
      7:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          exit2 = 8;
        } else {
          switch (ty2.TAG) {
            case /* Bool_ty */
            7:
              return {
                TAG: (
                  /* Bool_ty */
                  7
                ),
                _0: trans(ty1._0, ty2._0)
              };
            case /* Format_arg_ty */
            8:
              exit2 = 6;
              break;
            case /* Format_subst_ty */
            9:
              exit2 = 7;
              break;
            case /* Alpha_ty */
            10:
              exit2 = 1;
              break;
            case /* Theta_ty */
            11:
              exit2 = 2;
              break;
            case /* Any_ty */
            12:
              exit2 = 3;
              break;
            case /* Reader_ty */
            13:
              exit2 = 4;
              break;
            case /* Ignored_reader_ty */
            14:
              exit2 = 5;
              break;
          }
        }
        break;
      case /* Format_arg_ty */
      8:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              836,
              26
            ]
          });
        }
        switch (ty2.TAG) {
          case /* Format_arg_ty */
          8:
            return {
              TAG: (
                /* Format_arg_ty */
                8
              ),
              _0: trans(ty1._0, ty2._0),
              _1: trans(ty1._1, ty2._1)
            };
          case /* Alpha_ty */
          10:
            exit2 = 1;
            break;
          case /* Theta_ty */
          11:
            exit2 = 2;
            break;
          case /* Any_ty */
          12:
            exit2 = 3;
            break;
          case /* Reader_ty */
          13:
            exit2 = 4;
            break;
          case /* Ignored_reader_ty */
          14:
            exit2 = 5;
            break;
          default:
            throw new MelangeError("Assert_failure", {
              MEL_EXN_ID: "Assert_failure",
              _1: [
                "camlinternalFormat.cppo.ml",
                836,
                26
              ]
            });
        }
        break;
      case /* Format_subst_ty */
      9:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              846,
              28
            ]
          });
        }
        switch (ty2.TAG) {
          case /* Format_arg_ty */
          8:
            exit2 = 6;
            break;
          case /* Format_subst_ty */
          9:
            const ty = trans(symm(ty1._1), ty2._0);
            const match = fmtty_rel_det(ty);
            _1(
              match[1],
              /* Refl */
              0
            );
            _1(
              match[3],
              /* Refl */
              0
            );
            return {
              TAG: (
                /* Format_subst_ty */
                9
              ),
              _0: ty1._0,
              _1: ty2._1,
              _2: trans(ty1._2, ty2._2)
            };
          case /* Alpha_ty */
          10:
            exit2 = 1;
            break;
          case /* Theta_ty */
          11:
            exit2 = 2;
            break;
          case /* Any_ty */
          12:
            exit2 = 3;
            break;
          case /* Reader_ty */
          13:
            exit2 = 4;
            break;
          case /* Ignored_reader_ty */
          14:
            exit2 = 5;
            break;
          default:
            throw new MelangeError("Assert_failure", {
              MEL_EXN_ID: "Assert_failure",
              _1: [
                "camlinternalFormat.cppo.ml",
                846,
                28
              ]
            });
        }
        break;
      case /* Alpha_ty */
      10:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              814,
              21
            ]
          });
        }
        if (ty2.TAG === /* Alpha_ty */
        10) {
          return {
            TAG: (
              /* Alpha_ty */
              10
            ),
            _0: trans(ty1._0, ty2._0)
          };
        }
        throw new MelangeError("Assert_failure", {
          MEL_EXN_ID: "Assert_failure",
          _1: [
            "camlinternalFormat.cppo.ml",
            814,
            21
          ]
        });
      case /* Theta_ty */
      11:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              818,
              21
            ]
          });
        }
        switch (ty2.TAG) {
          case /* Alpha_ty */
          10:
            exit2 = 1;
            break;
          case /* Theta_ty */
          11:
            return {
              TAG: (
                /* Theta_ty */
                11
              ),
              _0: trans(ty1._0, ty2._0)
            };
          default:
            throw new MelangeError("Assert_failure", {
              MEL_EXN_ID: "Assert_failure",
              _1: [
                "camlinternalFormat.cppo.ml",
                818,
                21
              ]
            });
        }
        break;
      case /* Any_ty */
      12:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              822,
              19
            ]
          });
        }
        switch (ty2.TAG) {
          case /* Alpha_ty */
          10:
            exit2 = 1;
            break;
          case /* Theta_ty */
          11:
            exit2 = 2;
            break;
          case /* Any_ty */
          12:
            return {
              TAG: (
                /* Any_ty */
                12
              ),
              _0: trans(ty1._0, ty2._0)
            };
          default:
            throw new MelangeError("Assert_failure", {
              MEL_EXN_ID: "Assert_failure",
              _1: [
                "camlinternalFormat.cppo.ml",
                822,
                19
              ]
            });
        }
        break;
      case /* Reader_ty */
      13:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              826,
              22
            ]
          });
        }
        switch (ty2.TAG) {
          case /* Alpha_ty */
          10:
            exit2 = 1;
            break;
          case /* Theta_ty */
          11:
            exit2 = 2;
            break;
          case /* Any_ty */
          12:
            exit2 = 3;
            break;
          case /* Reader_ty */
          13:
            return {
              TAG: (
                /* Reader_ty */
                13
              ),
              _0: trans(ty1._0, ty2._0)
            };
          default:
            throw new MelangeError("Assert_failure", {
              MEL_EXN_ID: "Assert_failure",
              _1: [
                "camlinternalFormat.cppo.ml",
                826,
                22
              ]
            });
        }
        break;
      case /* Ignored_reader_ty */
      14:
        if (
          /* tag */
          typeof ty2 === "number" || typeof ty2 === "string"
        ) {
          throw new MelangeError("Assert_failure", {
            MEL_EXN_ID: "Assert_failure",
            _1: [
              "camlinternalFormat.cppo.ml",
              831,
              30
            ]
          });
        }
        switch (ty2.TAG) {
          case /* Alpha_ty */
          10:
            exit2 = 1;
            break;
          case /* Theta_ty */
          11:
            exit2 = 2;
            break;
          case /* Any_ty */
          12:
            exit2 = 3;
            break;
          case /* Reader_ty */
          13:
            exit2 = 4;
            break;
          case /* Ignored_reader_ty */
          14:
            return {
              TAG: (
                /* Ignored_reader_ty */
                14
              ),
              _0: trans(ty1._0, ty2._0)
            };
          default:
            throw new MelangeError("Assert_failure", {
              MEL_EXN_ID: "Assert_failure",
              _1: [
                "camlinternalFormat.cppo.ml",
                831,
                30
              ]
            });
        }
        break;
    }
  }
  switch (exit2) {
    case 1:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          815,
          21
        ]
      });
    case 2:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          819,
          21
        ]
      });
    case 3:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          823,
          19
        ]
      });
    case 4:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          827,
          22
        ]
      });
    case 5:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          832,
          30
        ]
      });
    case 6:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          837,
          26
        ]
      });
    case 7:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          847,
          28
        ]
      });
    case 8:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          851,
          23
        ]
      });
  }
}
var Type_mismatch = /* @__PURE__ */ create("CamlinternalFormat.Type_mismatch");
function type_padding(pad, fmtty) {
  if (
    /* tag */
    typeof pad === "number" || typeof pad === "string"
  ) {
    return {
      TAG: (
        /* Padding_fmtty_EBB */
        0
      ),
      _0: (
        /* No_padding */
        0
      ),
      _1: fmtty
    };
  }
  if (pad.TAG === /* Lit_padding */
  0) {
    return {
      TAG: (
        /* Padding_fmtty_EBB */
        0
      ),
      _0: {
        TAG: (
          /* Lit_padding */
          0
        ),
        _0: pad._0,
        _1: pad._1
      },
      _1: fmtty
    };
  }
  if (
    /* tag */
    typeof fmtty === "number" || typeof fmtty === "string"
  ) {
    throw new MelangeError(Type_mismatch, {
      MEL_EXN_ID: Type_mismatch
    });
  }
  if (fmtty.TAG === /* Int_ty */
  2) {
    return {
      TAG: (
        /* Padding_fmtty_EBB */
        0
      ),
      _0: {
        TAG: (
          /* Arg_padding */
          1
        ),
        _0: pad._0
      },
      _1: fmtty._0
    };
  }
  throw new MelangeError(Type_mismatch, {
    MEL_EXN_ID: Type_mismatch
  });
}
function type_padprec(pad, prec, fmtty) {
  const match = type_padding(pad, fmtty);
  if (!/* tag */
  (typeof prec === "number" || typeof prec === "string")) {
    return {
      TAG: (
        /* Padprec_fmtty_EBB */
        0
      ),
      _0: match._0,
      _1: {
        TAG: (
          /* Lit_precision */
          0
        ),
        _0: prec._0
      },
      _2: match._1
    };
  }
  if (prec === /* No_precision */
  0) {
    return {
      TAG: (
        /* Padprec_fmtty_EBB */
        0
      ),
      _0: match._0,
      _1: (
        /* No_precision */
        0
      ),
      _2: match._1
    };
  }
  const rest = match._1;
  if (
    /* tag */
    typeof rest === "number" || typeof rest === "string"
  ) {
    throw new MelangeError(Type_mismatch, {
      MEL_EXN_ID: Type_mismatch
    });
  }
  if (rest.TAG === /* Int_ty */
  2) {
    return {
      TAG: (
        /* Padprec_fmtty_EBB */
        0
      ),
      _0: match._0,
      _1: (
        /* Arg_precision */
        1
      ),
      _2: rest._0
    };
  }
  throw new MelangeError(Type_mismatch, {
    MEL_EXN_ID: Type_mismatch
  });
}
function type_ignored_format_substitution(sub_fmtty, fmt, fmtty) {
  if (
    /* tag */
    typeof sub_fmtty === "number" || typeof sub_fmtty === "string"
  ) {
    return {
      TAG: (
        /* Fmtty_fmt_EBB */
        0
      ),
      _0: (
        /* End_of_fmtty */
        0
      ),
      _1: type_format_gen(fmt, fmtty)
    };
  }
  switch (sub_fmtty.TAG) {
    case /* Char_ty */
    0:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Char_ty */
      0) {
        const match = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Char_ty */
              0
            ),
            _0: match._0
          },
          _1: match._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* String_ty */
    1:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* String_ty */
      1) {
        const match$1 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* String_ty */
              1
            ),
            _0: match$1._0
          },
          _1: match$1._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Int_ty */
    2:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Int_ty */
      2) {
        const match$2 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Int_ty */
              2
            ),
            _0: match$2._0
          },
          _1: match$2._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Int32_ty */
    3:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Int32_ty */
      3) {
        const match$3 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Int32_ty */
              3
            ),
            _0: match$3._0
          },
          _1: match$3._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Nativeint_ty */
    4:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Nativeint_ty */
      4) {
        const match$4 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Nativeint_ty */
              4
            ),
            _0: match$4._0
          },
          _1: match$4._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Int64_ty */
    5:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Int64_ty */
      5) {
        const match$5 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Int64_ty */
              5
            ),
            _0: match$5._0
          },
          _1: match$5._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Float_ty */
    6:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Float_ty */
      6) {
        const match$6 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Float_ty */
              6
            ),
            _0: match$6._0
          },
          _1: match$6._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Bool_ty */
    7:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Bool_ty */
      7) {
        const match$7 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Bool_ty */
              7
            ),
            _0: match$7._0
          },
          _1: match$7._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Format_arg_ty */
    8:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Format_arg_ty */
      8) {
        const sub2_fmtty$p = fmtty._0;
        if (caml_notequal({
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: sub_fmtty._0
        }, {
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: sub2_fmtty$p
        })) {
          throw new MelangeError(Type_mismatch, {
            MEL_EXN_ID: Type_mismatch
          });
        }
        const match$8 = type_ignored_format_substitution(sub_fmtty._1, fmt, fmtty._1);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Format_arg_ty */
              8
            ),
            _0: sub2_fmtty$p,
            _1: match$8._0
          },
          _1: match$8._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Format_subst_ty */
    9:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Format_subst_ty */
      9) {
        const sub2_fmtty$p$1 = fmtty._1;
        const sub1_fmtty$p = fmtty._0;
        if (caml_notequal({
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: erase_rel(sub_fmtty._0)
        }, {
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: erase_rel(sub1_fmtty$p)
        })) {
          throw new MelangeError(Type_mismatch, {
            MEL_EXN_ID: Type_mismatch
          });
        }
        if (caml_notequal({
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: erase_rel(sub_fmtty._1)
        }, {
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: erase_rel(sub2_fmtty$p$1)
        })) {
          throw new MelangeError(Type_mismatch, {
            MEL_EXN_ID: Type_mismatch
          });
        }
        const sub_fmtty$p = trans(symm(sub1_fmtty$p), sub2_fmtty$p$1);
        const match$9 = fmtty_rel_det(sub_fmtty$p);
        _1(
          match$9[1],
          /* Refl */
          0
        );
        _1(
          match$9[3],
          /* Refl */
          0
        );
        const match$10 = type_ignored_format_substitution(erase_rel(sub_fmtty._2), fmt, fmtty._2);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Format_subst_ty */
              9
            ),
            _0: sub1_fmtty$p,
            _1: sub2_fmtty$p$1,
            _2: symm(match$10._0)
          },
          _1: match$10._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Alpha_ty */
    10:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Alpha_ty */
      10) {
        const match$11 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Alpha_ty */
              10
            ),
            _0: match$11._0
          },
          _1: match$11._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Theta_ty */
    11:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Theta_ty */
      11) {
        const match$12 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Theta_ty */
              11
            ),
            _0: match$12._0
          },
          _1: match$12._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Any_ty */
    12:
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Reader_ty */
    13:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Reader_ty */
      13) {
        const match$13 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Reader_ty */
              13
            ),
            _0: match$13._0
          },
          _1: match$13._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Ignored_reader_ty */
    14:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Ignored_reader_ty */
      14) {
        const match$14 = type_ignored_format_substitution(sub_fmtty._0, fmt, fmtty._0);
        return {
          TAG: (
            /* Fmtty_fmt_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Ignored_reader_ty */
              14
            ),
            _0: match$14._0
          },
          _1: match$14._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
  }
}
function type_ignored_param_one(ign, fmt, fmtty) {
  const match = type_format_gen(fmt, fmtty);
  return {
    TAG: (
      /* Fmt_fmtty_EBB */
      0
    ),
    _0: {
      TAG: (
        /* Ignored_param */
        23
      ),
      _0: ign,
      _1: match._0
    },
    _1: match._1
  };
}
function type_format_gen(fmt, fmtty) {
  if (
    /* tag */
    typeof fmt === "number" || typeof fmt === "string"
  ) {
    return {
      TAG: (
        /* Fmt_fmtty_EBB */
        0
      ),
      _0: (
        /* End_of_format */
        0
      ),
      _1: fmtty
    };
  }
  switch (fmt.TAG) {
    case /* Char */
    0:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Char_ty */
      0) {
        const match = type_format_gen(fmt._0, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Char */
              0
            ),
            _0: match._0
          },
          _1: match._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Caml_char */
    1:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Char_ty */
      0) {
        const match$1 = type_format_gen(fmt._0, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Caml_char */
              1
            ),
            _0: match$1._0
          },
          _1: match$1._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* String */
    2:
      const match$2 = type_padding(fmt._0, fmtty);
      const fmtty_rest = match$2._1;
      if (
        /* tag */
        typeof fmtty_rest === "number" || typeof fmtty_rest === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest.TAG === /* String_ty */
      1) {
        const match$3 = type_format_gen(fmt._1, fmtty_rest._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* String */
              2
            ),
            _0: match$2._0,
            _1: match$3._0
          },
          _1: match$3._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Caml_string */
    3:
      const match$4 = type_padding(fmt._0, fmtty);
      const fmtty_rest$1 = match$4._1;
      if (
        /* tag */
        typeof fmtty_rest$1 === "number" || typeof fmtty_rest$1 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$1.TAG === /* String_ty */
      1) {
        const match$5 = type_format_gen(fmt._1, fmtty_rest$1._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Caml_string */
              3
            ),
            _0: match$4._0,
            _1: match$5._0
          },
          _1: match$5._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Int */
    4:
      const match$6 = type_padprec(fmt._1, fmt._2, fmtty);
      const fmtty_rest$2 = match$6._2;
      if (
        /* tag */
        typeof fmtty_rest$2 === "number" || typeof fmtty_rest$2 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$2.TAG === /* Int_ty */
      2) {
        const match$7 = type_format_gen(fmt._3, fmtty_rest$2._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Int */
              4
            ),
            _0: fmt._0,
            _1: match$6._0,
            _2: match$6._1,
            _3: match$7._0
          },
          _1: match$7._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Int32 */
    5:
      const match$8 = type_padprec(fmt._1, fmt._2, fmtty);
      const fmtty_rest$3 = match$8._2;
      if (
        /* tag */
        typeof fmtty_rest$3 === "number" || typeof fmtty_rest$3 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$3.TAG === /* Int32_ty */
      3) {
        const match$9 = type_format_gen(fmt._3, fmtty_rest$3._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Int32 */
              5
            ),
            _0: fmt._0,
            _1: match$8._0,
            _2: match$8._1,
            _3: match$9._0
          },
          _1: match$9._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Nativeint */
    6:
      const match$10 = type_padprec(fmt._1, fmt._2, fmtty);
      const fmtty_rest$4 = match$10._2;
      if (
        /* tag */
        typeof fmtty_rest$4 === "number" || typeof fmtty_rest$4 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$4.TAG === /* Nativeint_ty */
      4) {
        const match$11 = type_format_gen(fmt._3, fmtty_rest$4._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Nativeint */
              6
            ),
            _0: fmt._0,
            _1: match$10._0,
            _2: match$10._1,
            _3: match$11._0
          },
          _1: match$11._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Int64 */
    7:
      const match$12 = type_padprec(fmt._1, fmt._2, fmtty);
      const fmtty_rest$5 = match$12._2;
      if (
        /* tag */
        typeof fmtty_rest$5 === "number" || typeof fmtty_rest$5 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$5.TAG === /* Int64_ty */
      5) {
        const match$13 = type_format_gen(fmt._3, fmtty_rest$5._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Int64 */
              7
            ),
            _0: fmt._0,
            _1: match$12._0,
            _2: match$12._1,
            _3: match$13._0
          },
          _1: match$13._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Float */
    8:
      const match$14 = type_padprec(fmt._1, fmt._2, fmtty);
      const fmtty_rest$6 = match$14._2;
      if (
        /* tag */
        typeof fmtty_rest$6 === "number" || typeof fmtty_rest$6 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$6.TAG === /* Float_ty */
      6) {
        const match$15 = type_format_gen(fmt._3, fmtty_rest$6._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Float */
              8
            ),
            _0: fmt._0,
            _1: match$14._0,
            _2: match$14._1,
            _3: match$15._0
          },
          _1: match$15._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Bool */
    9:
      const match$16 = type_padding(fmt._0, fmtty);
      const fmtty_rest$7 = match$16._1;
      if (
        /* tag */
        typeof fmtty_rest$7 === "number" || typeof fmtty_rest$7 === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty_rest$7.TAG === /* Bool_ty */
      7) {
        const match$17 = type_format_gen(fmt._1, fmtty_rest$7._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Bool */
              9
            ),
            _0: match$16._0,
            _1: match$17._0
          },
          _1: match$17._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Flush */
    10:
      const match$18 = type_format_gen(fmt._0, fmtty);
      return {
        TAG: (
          /* Fmt_fmtty_EBB */
          0
        ),
        _0: {
          TAG: (
            /* Flush */
            10
          ),
          _0: match$18._0
        },
        _1: match$18._1
      };
    case /* String_literal */
    11:
      const match$19 = type_format_gen(fmt._1, fmtty);
      return {
        TAG: (
          /* Fmt_fmtty_EBB */
          0
        ),
        _0: {
          TAG: (
            /* String_literal */
            11
          ),
          _0: fmt._0,
          _1: match$19._0
        },
        _1: match$19._1
      };
    case /* Char_literal */
    12:
      const match$20 = type_format_gen(fmt._1, fmtty);
      return {
        TAG: (
          /* Fmt_fmtty_EBB */
          0
        ),
        _0: {
          TAG: (
            /* Char_literal */
            12
          ),
          _0: fmt._0,
          _1: match$20._0
        },
        _1: match$20._1
      };
    case /* Format_arg */
    13:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Format_arg_ty */
      8) {
        const sub_fmtty$p = fmtty._0;
        if (caml_notequal({
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: fmt._1
        }, {
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: sub_fmtty$p
        })) {
          throw new MelangeError(Type_mismatch, {
            MEL_EXN_ID: Type_mismatch
          });
        }
        const match$21 = type_format_gen(fmt._2, fmtty._1);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Format_arg */
              13
            ),
            _0: fmt._0,
            _1: sub_fmtty$p,
            _2: match$21._0
          },
          _1: match$21._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Format_subst */
    14:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Format_subst_ty */
      9) {
        const sub_fmtty1 = fmtty._0;
        if (caml_notequal({
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: erase_rel(fmt._1)
        }, {
          TAG: (
            /* Fmtty_EBB */
            0
          ),
          _0: erase_rel(sub_fmtty1)
        })) {
          throw new MelangeError(Type_mismatch, {
            MEL_EXN_ID: Type_mismatch
          });
        }
        const match$22 = type_format_gen(fmt._2, erase_rel(fmtty._2));
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Format_subst */
              14
            ),
            _0: fmt._0,
            _1: sub_fmtty1,
            _2: match$22._0
          },
          _1: match$22._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Alpha */
    15:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Alpha_ty */
      10) {
        const match$23 = type_format_gen(fmt._0, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Alpha */
              15
            ),
            _0: match$23._0
          },
          _1: match$23._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Theta */
    16:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Theta_ty */
      11) {
        const match$24 = type_format_gen(fmt._0, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Theta */
              16
            ),
            _0: match$24._0
          },
          _1: match$24._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Formatting_lit */
    17:
      const match$25 = type_format_gen(fmt._1, fmtty);
      return {
        TAG: (
          /* Fmt_fmtty_EBB */
          0
        ),
        _0: {
          TAG: (
            /* Formatting_lit */
            17
          ),
          _0: fmt._0,
          _1: match$25._0
        },
        _1: match$25._1
      };
    case /* Formatting_gen */
    18:
      let formatting_gen = fmt._0;
      let fmt0 = fmt._1;
      if (formatting_gen.TAG === /* Open_tag */
      0) {
        const match$26 = formatting_gen._0;
        const match$27 = type_format_gen(match$26._0, fmtty);
        const match$28 = type_format_gen(fmt0, match$27._1);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Formatting_gen */
              18
            ),
            _0: {
              TAG: (
                /* Open_tag */
                0
              ),
              _0: {
                TAG: (
                  /* Format */
                  0
                ),
                _0: match$27._0,
                _1: match$26._1
              }
            },
            _1: match$28._0
          },
          _1: match$28._1
        };
      }
      const match$29 = formatting_gen._0;
      const match$30 = type_format_gen(match$29._0, fmtty);
      const match$31 = type_format_gen(fmt0, match$30._1);
      return {
        TAG: (
          /* Fmt_fmtty_EBB */
          0
        ),
        _0: {
          TAG: (
            /* Formatting_gen */
            18
          ),
          _0: {
            TAG: (
              /* Open_box */
              1
            ),
            _0: {
              TAG: (
                /* Format */
                0
              ),
              _0: match$30._0,
              _1: match$29._1
            }
          },
          _1: match$31._0
        },
        _1: match$31._1
      };
    case /* Reader */
    19:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Reader_ty */
      13) {
        const match$32 = type_format_gen(fmt._0, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Reader */
              19
            ),
            _0: match$32._0
          },
          _1: match$32._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Scan_char_set */
    20:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* String_ty */
      1) {
        const match$33 = type_format_gen(fmt._2, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Scan_char_set */
              20
            ),
            _0: fmt._0,
            _1: fmt._1,
            _2: match$33._0
          },
          _1: match$33._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Scan_get_counter */
    21:
      if (
        /* tag */
        typeof fmtty === "number" || typeof fmtty === "string"
      ) {
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      }
      if (fmtty.TAG === /* Int_ty */
      2) {
        const match$34 = type_format_gen(fmt._1, fmtty._0);
        return {
          TAG: (
            /* Fmt_fmtty_EBB */
            0
          ),
          _0: {
            TAG: (
              /* Scan_get_counter */
              21
            ),
            _0: fmt._0,
            _1: match$34._0
          },
          _1: match$34._1
        };
      }
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
    case /* Ignored_param */
    23:
      let ign = fmt._0;
      let fmt$1 = fmt._1;
      if (
        /* tag */
        typeof ign === "number" || typeof ign === "string"
      ) {
        if (ign !== /* Ignored_reader */
        2) {
          return type_ignored_param_one(ign, fmt$1, fmtty);
        }
        if (
          /* tag */
          typeof fmtty === "number" || typeof fmtty === "string"
        ) {
          throw new MelangeError(Type_mismatch, {
            MEL_EXN_ID: Type_mismatch
          });
        }
        if (fmtty.TAG === /* Ignored_reader_ty */
        14) {
          const match$35 = type_format_gen(fmt$1, fmtty._0);
          return {
            TAG: (
              /* Fmt_fmtty_EBB */
              0
            ),
            _0: {
              TAG: (
                /* Ignored_param */
                23
              ),
              _0: (
                /* Ignored_reader */
                2
              ),
              _1: match$35._0
            },
            _1: match$35._1
          };
        }
        throw new MelangeError(Type_mismatch, {
          MEL_EXN_ID: Type_mismatch
        });
      } else {
        switch (ign.TAG) {
          case /* Ignored_format_arg */
          8:
            return type_ignored_param_one({
              TAG: (
                /* Ignored_format_arg */
                8
              ),
              _0: ign._0,
              _1: ign._1
            }, fmt$1, fmtty);
          case /* Ignored_format_subst */
          9:
            const match$36 = type_ignored_format_substitution(ign._1, fmt$1, fmtty);
            const match$37 = match$36._1;
            return {
              TAG: (
                /* Fmt_fmtty_EBB */
                0
              ),
              _0: {
                TAG: (
                  /* Ignored_param */
                  23
                ),
                _0: {
                  TAG: (
                    /* Ignored_format_subst */
                    9
                  ),
                  _0: ign._0,
                  _1: match$36._0
                },
                _1: match$37._0
              },
              _1: match$37._1
            };
          default:
            return type_ignored_param_one(ign, fmt$1, fmtty);
        }
      }
    case /* Scan_next_char */
    22:
    case /* Custom */
    24:
      throw new MelangeError(Type_mismatch, {
        MEL_EXN_ID: Type_mismatch
      });
  }
}
function type_format(fmt, fmtty) {
  const match = type_format_gen(fmt, fmtty);
  let tmp = match._1;
  if (
    /* tag */
    typeof tmp === "number" || typeof tmp === "string"
  ) {
    return match._0;
  }
  throw new MelangeError(Type_mismatch, {
    MEL_EXN_ID: Type_mismatch
  });
}
function recast(fmt, fmtty) {
  return type_format(fmt, erase_rel(symm(fmtty)));
}
function fix_padding(padty, width, str) {
  const len = str.length;
  const width$1 = abs(width);
  const padty$1 = width < 0 ? (
    /* Left */
    0
  ) : padty;
  if (width$1 <= len) {
    return str;
  }
  const res = make4(width$1, padty$1 === /* Zeros */
  2 ? (
    /* '0' */
    48
  ) : (
    /* ' ' */
    32
  ));
  switch (padty$1) {
    case /* Left */
    0:
      blit4(str, 0, res, 0, len);
      break;
    case /* Right */
    1:
      blit4(str, 0, res, width$1 - len | 0, len);
      break;
    case /* Zeros */
    2:
      if (len > 0 && (get(str, 0) === /* '+' */
      43 || get(str, 0) === /* '-' */
      45 || get(str, 0) === /* ' ' */
      32)) {
        set2(res, 0, get(str, 0));
        blit4(str, 1, res, (width$1 - len | 0) + 1 | 0, len - 1 | 0);
      } else if (len > 1 && get(str, 0) === /* '0' */
      48 && (get(str, 1) === /* 'x' */
      120 || get(str, 1) === /* 'X' */
      88)) {
        set2(res, 1, get(str, 1));
        blit4(str, 2, res, (width$1 - len | 0) + 2 | 0, len - 2 | 0);
      } else {
        blit4(str, 0, res, width$1 - len | 0, len);
      }
      break;
  }
  return bytes_to_string(res);
}
function fix_int_precision(prec, str) {
  const prec$1 = abs(prec);
  const len = str.length;
  const c = get(str, 0);
  let exit2 = 0;
  if (c >= 58) {
    if (c >= 71) {
      if (c > 102 || c < 97) {
        return str;
      }
      exit2 = 2;
    } else {
      if (c < 65) {
        return str;
      }
      exit2 = 2;
    }
  } else if (c !== 32) {
    if (c < 43) {
      return str;
    }
    switch (c) {
      case 43:
      case 45:
        exit2 = 1;
        break;
      case 44:
      case 46:
      case 47:
        return str;
      case 48:
        if ((prec$1 + 2 | 0) > len && len > 1 && (get(str, 1) === /* 'x' */
        120 || get(str, 1) === /* 'X' */
        88)) {
          const res = make4(
            prec$1 + 2 | 0,
            /* '0' */
            48
          );
          set2(res, 1, get(str, 1));
          blit4(str, 2, res, (prec$1 - len | 0) + 4 | 0, len - 2 | 0);
          return bytes_to_string(res);
        }
        exit2 = 2;
        break;
      case 49:
      case 50:
      case 51:
      case 52:
      case 53:
      case 54:
      case 55:
      case 56:
      case 57:
        exit2 = 2;
        break;
    }
  } else {
    exit2 = 1;
  }
  switch (exit2) {
    case 1:
      if ((prec$1 + 1 | 0) <= len) {
        return str;
      }
      const res$1 = make4(
        prec$1 + 1 | 0,
        /* '0' */
        48
      );
      set2(res$1, 0, c);
      blit4(str, 1, res$1, (prec$1 - len | 0) + 2 | 0, len - 1 | 0);
      return bytes_to_string(res$1);
    case 2:
      if (prec$1 <= len) {
        return str;
      }
      const res$2 = make4(
        prec$1,
        /* '0' */
        48
      );
      blit4(str, 0, res$2, prec$1 - len | 0, len);
      return bytes_to_string(res$2);
  }
}
function string_to_caml_string(str) {
  const str$1 = escaped2(str);
  const l = str$1.length;
  const res = make4(
    l + 2 | 0,
    /* '"' */
    34
  );
  caml_blit_string(str$1, 0, res, 1, l);
  return bytes_to_string(res);
}
function format_of_iconv(param) {
  switch (param) {
    case /* Int_pd */
    1:
      return "%+d";
    case /* Int_sd */
    2:
      return "% d";
    case /* Int_pi */
    4:
      return "%+i";
    case /* Int_si */
    5:
      return "% i";
    case /* Int_x */
    6:
      return "%x";
    case /* Int_Cx */
    7:
      return "%#x";
    case /* Int_X */
    8:
      return "%X";
    case /* Int_CX */
    9:
      return "%#X";
    case /* Int_o */
    10:
      return "%o";
    case /* Int_Co */
    11:
      return "%#o";
    case /* Int_d */
    0:
    case /* Int_Cd */
    13:
      return "%d";
    case /* Int_i */
    3:
    case /* Int_Ci */
    14:
      return "%i";
    case /* Int_u */
    12:
    case /* Int_Cu */
    15:
      return "%u";
  }
}
function format_of_iconvL(param) {
  switch (param) {
    case /* Int_pd */
    1:
      return "%+Ld";
    case /* Int_sd */
    2:
      return "% Ld";
    case /* Int_pi */
    4:
      return "%+Li";
    case /* Int_si */
    5:
      return "% Li";
    case /* Int_x */
    6:
      return "%Lx";
    case /* Int_Cx */
    7:
      return "%#Lx";
    case /* Int_X */
    8:
      return "%LX";
    case /* Int_CX */
    9:
      return "%#LX";
    case /* Int_o */
    10:
      return "%Lo";
    case /* Int_Co */
    11:
      return "%#Lo";
    case /* Int_d */
    0:
    case /* Int_Cd */
    13:
      return "%Ld";
    case /* Int_i */
    3:
    case /* Int_Ci */
    14:
      return "%Li";
    case /* Int_u */
    12:
    case /* Int_Cu */
    15:
      return "%Lu";
  }
}
function format_of_iconvl(param) {
  switch (param) {
    case /* Int_pd */
    1:
      return "%+ld";
    case /* Int_sd */
    2:
      return "% ld";
    case /* Int_pi */
    4:
      return "%+li";
    case /* Int_si */
    5:
      return "% li";
    case /* Int_x */
    6:
      return "%lx";
    case /* Int_Cx */
    7:
      return "%#lx";
    case /* Int_X */
    8:
      return "%lX";
    case /* Int_CX */
    9:
      return "%#lX";
    case /* Int_o */
    10:
      return "%lo";
    case /* Int_Co */
    11:
      return "%#lo";
    case /* Int_d */
    0:
    case /* Int_Cd */
    13:
      return "%ld";
    case /* Int_i */
    3:
    case /* Int_Ci */
    14:
      return "%li";
    case /* Int_u */
    12:
    case /* Int_Cu */
    15:
      return "%lu";
  }
}
function format_of_iconvn(param) {
  switch (param) {
    case /* Int_pd */
    1:
      return "%+nd";
    case /* Int_sd */
    2:
      return "% nd";
    case /* Int_pi */
    4:
      return "%+ni";
    case /* Int_si */
    5:
      return "% ni";
    case /* Int_x */
    6:
      return "%nx";
    case /* Int_Cx */
    7:
      return "%#nx";
    case /* Int_X */
    8:
      return "%nX";
    case /* Int_CX */
    9:
      return "%#nX";
    case /* Int_o */
    10:
      return "%no";
    case /* Int_Co */
    11:
      return "%#no";
    case /* Int_d */
    0:
    case /* Int_Cd */
    13:
      return "%nd";
    case /* Int_i */
    3:
    case /* Int_Ci */
    14:
      return "%ni";
    case /* Int_u */
    12:
    case /* Int_Cu */
    15:
      return "%nu";
  }
}
function format_of_fconv(fconv, prec) {
  const prec$1 = abs(prec);
  const symb = char_of_fconv(
    /* 'g' */
    103,
    fconv
  );
  const buf = {
    ind: 0,
    bytes: caml_create_bytes(16)
  };
  buffer_add_char(
    buf,
    /* '%' */
    37
  );
  bprint_fconv_flag(buf, fconv);
  buffer_add_char(
    buf,
    /* '.' */
    46
  );
  buffer_add_string(buf, caml_format_int("%d", prec$1));
  buffer_add_char(buf, symb);
  return buffer_contents(buf);
}
function transform_int_alt(iconv, s) {
  switch (iconv) {
    case /* Int_Cd */
    13:
    case /* Int_Ci */
    14:
    case /* Int_Cu */
    15:
      break;
    default:
      return s;
  }
  let n = 0;
  for (let i = 0, i_finish = s.length; i < i_finish; ++i) {
    const match = s.charCodeAt(i);
    if (!(match > 57 || match < 48)) {
      n = n + 1 | 0;
    }
  }
  const digits = n;
  const buf = caml_create_bytes(s.length + ((digits - 1 | 0) / 3 | 0) | 0);
  const pos = {
    contents: 0
  };
  const put = function(c) {
    set2(buf, pos.contents, c);
    pos.contents = pos.contents + 1 | 0;
  };
  let left = (digits - 1 | 0) % 3 + 1 | 0;
  for (let i$1 = 0, i_finish$1 = s.length; i$1 < i_finish$1; ++i$1) {
    const c = s.charCodeAt(i$1);
    if (c > 57 || c < 48) {
      put(c);
    } else {
      if (left === 0) {
        put(
          /* '_' */
          95
        );
        left = 3;
      }
      left = left - 1 | 0;
      put(c);
    }
  }
  return bytes_to_string(buf);
}
function convert_int(iconv, n) {
  return transform_int_alt(iconv, caml_format_int(format_of_iconv(iconv), n));
}
function convert_int32(iconv, n) {
  return transform_int_alt(iconv, caml_int32_format(format_of_iconvl(iconv), n));
}
function convert_nativeint(iconv, n) {
  return transform_int_alt(iconv, caml_nativeint_format(format_of_iconvn(iconv), n));
}
function convert_int64(iconv, n) {
  return transform_int_alt(iconv, caml_int64_format(format_of_iconvL(iconv), n));
}
function convert_float(fconv, prec, x) {
  const hex = function(param) {
    const match2 = fconv[0];
    let sign;
    switch (match2) {
      case /* Float_flag_ */
      0:
        sign = /* '-' */
        45;
        break;
      case /* Float_flag_p */
      1:
        sign = /* '+' */
        43;
        break;
      case /* Float_flag_s */
      2:
        sign = /* ' ' */
        32;
        break;
    }
    return caml_hexstring_of_float(x, prec, sign);
  };
  const add_dot_if_needed = function(str) {
    const len = str.length;
    const is_valid = function(_i) {
      while (true) {
        const i = _i;
        if (i === len) {
          return false;
        }
        const match2 = get(str, i);
        if (match2 > 69 || match2 < 46) {
          if (match2 === 101) {
            return true;
          }
          _i = i + 1 | 0;
          continue;
        }
        if (match2 > 68 || match2 < 47) {
          return true;
        }
        _i = i + 1 | 0;
        continue;
      }
      ;
    };
    if (is_valid(0)) {
      return str;
    } else {
      return str + ".";
    }
  };
  const caml_special_val = function(str) {
    const match2 = classify_float(x);
    switch (match2) {
      case /* FP_infinite */
      3:
        if (x < 0) {
          return "neg_infinity";
        } else {
          return "infinity";
        }
      case /* FP_nan */
      4:
        return "nan";
      default:
        return str;
    }
  };
  const match = fconv[1];
  switch (match) {
    case /* Float_F */
    5:
      const str = caml_format_float(format_of_fconv(fconv, prec), x);
      return caml_special_val(add_dot_if_needed(str));
    case /* Float_h */
    6:
      return hex();
    case /* Float_H */
    7:
      const s = hex();
      return bytes_to_string(uppercase_ascii2(bytes_of_string(s)));
    case /* Float_CF */
    8:
      return caml_special_val(hex());
    default:
      return caml_format_float(format_of_fconv(fconv, prec), x);
  }
}
function format_caml_char(c) {
  const str = escaped(c);
  const l = str.length;
  const res = make4(
    l + 2 | 0,
    /* '\'' */
    39
  );
  caml_blit_string(str, 0, res, 1, l);
  return bytes_to_string(res);
}
function string_of_fmtty(fmtty) {
  const buf = {
    ind: 0,
    bytes: caml_create_bytes(16)
  };
  bprint_fmtty(buf, fmtty);
  return buffer_contents(buf);
}
function make_printf(_k, _acc, _fmt) {
  while (true) {
    const fmt = _fmt;
    const acc = _acc;
    const k = _k;
    if (
      /* tag */
      typeof fmt === "number" || typeof fmt === "string"
    ) {
      return _1(k, acc);
    }
    switch (fmt.TAG) {
      case /* Char */
      0:
        const rest = fmt._0;
        return function(c) {
          const new_acc2 = {
            TAG: (
              /* Acc_data_char */
              5
            ),
            _0: acc,
            _1: c
          };
          return make_printf(k, new_acc2, rest);
        };
      case /* Caml_char */
      1:
        const rest$1 = fmt._0;
        return function(c) {
          const new_acc_1 = format_caml_char(c);
          const new_acc2 = {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: new_acc_1
          };
          return make_printf(k, new_acc2, rest$1);
        };
      case /* String */
      2:
        return make_padding(k, acc, fmt._1, fmt._0, (function(str) {
          return str;
        }));
      case /* Caml_string */
      3:
        return make_padding(k, acc, fmt._1, fmt._0, string_to_caml_string);
      case /* Int */
      4:
        return make_int_padding_precision(k, acc, fmt._3, fmt._1, fmt._2, convert_int, fmt._0);
      case /* Int32 */
      5:
        return make_int_padding_precision(k, acc, fmt._3, fmt._1, fmt._2, convert_int32, fmt._0);
      case /* Nativeint */
      6:
        return make_int_padding_precision(k, acc, fmt._3, fmt._1, fmt._2, convert_nativeint, fmt._0);
      case /* Int64 */
      7:
        return make_int_padding_precision(k, acc, fmt._3, fmt._1, fmt._2, convert_int64, fmt._0);
      case /* Float */
      8:
        let fmt$1 = fmt._3;
        let pad = fmt._1;
        let prec = fmt._2;
        let fconv = fmt._0;
        if (
          /* tag */
          typeof pad === "number" || typeof pad === "string"
        ) {
          if (
            /* tag */
            typeof prec === "number" || typeof prec === "string"
          ) {
            if (prec === /* No_precision */
            0) {
              return function(x) {
                const str = convert_float(fconv, default_float_precision(fconv), x);
                return make_printf(k, {
                  TAG: (
                    /* Acc_data_string */
                    4
                  ),
                  _0: acc,
                  _1: str
                }, fmt$1);
              };
            } else {
              return function(p2, x) {
                const str = convert_float(fconv, p2, x);
                return make_printf(k, {
                  TAG: (
                    /* Acc_data_string */
                    4
                  ),
                  _0: acc,
                  _1: str
                }, fmt$1);
              };
            }
          }
          const p = prec._0;
          return function(x) {
            const str = convert_float(fconv, p, x);
            return make_printf(k, {
              TAG: (
                /* Acc_data_string */
                4
              ),
              _0: acc,
              _1: str
            }, fmt$1);
          };
        }
        if (pad.TAG === /* Lit_padding */
        0) {
          const w = pad._1;
          const padty = pad._0;
          if (
            /* tag */
            typeof prec === "number" || typeof prec === "string"
          ) {
            if (prec === /* No_precision */
            0) {
              return function(x) {
                const str = convert_float(fconv, default_float_precision(fconv), x);
                const str$p = fix_padding(padty, w, str);
                return make_printf(k, {
                  TAG: (
                    /* Acc_data_string */
                    4
                  ),
                  _0: acc,
                  _1: str$p
                }, fmt$1);
              };
            } else {
              return function(p, x) {
                const str = fix_padding(padty, w, convert_float(fconv, p, x));
                return make_printf(k, {
                  TAG: (
                    /* Acc_data_string */
                    4
                  ),
                  _0: acc,
                  _1: str
                }, fmt$1);
              };
            }
          }
          const p$1 = prec._0;
          return function(x) {
            const str = fix_padding(padty, w, convert_float(fconv, p$1, x));
            return make_printf(k, {
              TAG: (
                /* Acc_data_string */
                4
              ),
              _0: acc,
              _1: str
            }, fmt$1);
          };
        }
        const padty$1 = pad._0;
        if (
          /* tag */
          typeof prec === "number" || typeof prec === "string"
        ) {
          if (prec === /* No_precision */
          0) {
            return function(w, x) {
              const str = convert_float(fconv, default_float_precision(fconv), x);
              const str$p = fix_padding(padty$1, w, str);
              return make_printf(k, {
                TAG: (
                  /* Acc_data_string */
                  4
                ),
                _0: acc,
                _1: str$p
              }, fmt$1);
            };
          } else {
            return function(w, p, x) {
              const str = fix_padding(padty$1, w, convert_float(fconv, p, x));
              return make_printf(k, {
                TAG: (
                  /* Acc_data_string */
                  4
                ),
                _0: acc,
                _1: str
              }, fmt$1);
            };
          }
        }
        const p$2 = prec._0;
        return function(w, x) {
          const str = fix_padding(padty$1, w, convert_float(fconv, p$2, x));
          return make_printf(k, {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: str
          }, fmt$1);
        };
      case /* Bool */
      9:
        return make_padding(k, acc, fmt._1, fmt._0, string_of_bool);
      case /* Flush */
      10:
        _fmt = fmt._0;
        _acc = {
          TAG: (
            /* Acc_flush */
            7
          ),
          _0: acc
        };
        continue;
      case /* String_literal */
      11:
        _fmt = fmt._1;
        _acc = {
          TAG: (
            /* Acc_string_literal */
            2
          ),
          _0: acc,
          _1: fmt._0
        };
        continue;
      case /* Char_literal */
      12:
        _fmt = fmt._1;
        _acc = {
          TAG: (
            /* Acc_char_literal */
            3
          ),
          _0: acc,
          _1: fmt._0
        };
        continue;
      case /* Format_arg */
      13:
        const rest$2 = fmt._2;
        const ty = string_of_fmtty(fmt._1);
        return function(str) {
          return make_printf(k, {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: ty
          }, rest$2);
        };
      case /* Format_subst */
      14:
        const rest$3 = fmt._2;
        const fmtty = fmt._1;
        return function(param) {
          return make_printf(k, acc, concat_fmt(recast(param._0, fmtty), rest$3));
        };
      case /* Alpha */
      15:
        const rest$4 = fmt._0;
        return function(f, x) {
          return make_printf(k, {
            TAG: (
              /* Acc_delay */
              6
            ),
            _0: acc,
            _1: (function(o) {
              return _2(f, o, x);
            })
          }, rest$4);
        };
      case /* Theta */
      16:
        const rest$5 = fmt._0;
        return function(f) {
          return make_printf(k, {
            TAG: (
              /* Acc_delay */
              6
            ),
            _0: acc,
            _1: f
          }, rest$5);
        };
      case /* Formatting_lit */
      17:
        _fmt = fmt._1;
        _acc = {
          TAG: (
            /* Acc_formatting_lit */
            0
          ),
          _0: acc,
          _1: fmt._0
        };
        continue;
      case /* Formatting_gen */
      18:
        const match = fmt._0;
        if (match.TAG === /* Open_tag */
        0) {
          const rest$6 = fmt._1;
          const k$p = function(kacc) {
            return make_printf(k, {
              TAG: (
                /* Acc_formatting_gen */
                1
              ),
              _0: acc,
              _1: {
                TAG: (
                  /* Acc_open_tag */
                  0
                ),
                _0: kacc
              }
            }, rest$6);
          };
          _fmt = match._0._0;
          _acc = /* End_of_acc */
          0;
          _k = k$p;
          continue;
        }
        const rest$7 = fmt._1;
        const k$p$1 = function(kacc) {
          return make_printf(k, {
            TAG: (
              /* Acc_formatting_gen */
              1
            ),
            _0: acc,
            _1: {
              TAG: (
                /* Acc_open_box */
                1
              ),
              _0: kacc
            }
          }, rest$7);
        };
        _fmt = match._0._0;
        _acc = /* End_of_acc */
        0;
        _k = k$p$1;
        continue;
      case /* Reader */
      19:
        throw new MelangeError("Assert_failure", {
          MEL_EXN_ID: "Assert_failure",
          _1: [
            "camlinternalFormat.cppo.ml",
            1558,
            4
          ]
        });
      case /* Scan_char_set */
      20:
        const rest$8 = fmt._2;
        const new_acc = {
          TAG: (
            /* Acc_invalid_arg */
            8
          ),
          _0: acc,
          _1: "Printf: bad conversion %["
        };
        return function(param) {
          return make_printf(k, new_acc, rest$8);
        };
      case /* Scan_get_counter */
      21:
        const rest$9 = fmt._1;
        return function(n) {
          const new_acc_1 = caml_format_int("%u", n);
          const new_acc2 = {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: new_acc_1
          };
          return make_printf(k, new_acc2, rest$9);
        };
      case /* Scan_next_char */
      22:
        const rest$10 = fmt._0;
        return function(c) {
          const new_acc2 = {
            TAG: (
              /* Acc_data_char */
              5
            ),
            _0: acc,
            _1: c
          };
          return make_printf(k, new_acc2, rest$10);
        };
      case /* Ignored_param */
      23:
        return make_ignored_param(k, acc, fmt._0, fmt._1);
      case /* Custom */
      24:
        return make_custom(k, acc, fmt._2, fmt._0, _1(fmt._1, void 0));
    }
  }
  ;
}
function make_ignored_param(k, acc, ign, fmt) {
  if (!/* tag */
  (typeof ign === "number" || typeof ign === "string")) {
    if (ign.TAG === /* Ignored_format_subst */
    9) {
      return make_from_fmtty(k, acc, ign._1, fmt);
    } else {
      return make_invalid_arg(k, acc, fmt);
    }
  }
  if (ign !== /* Ignored_reader */
  2) {
    return make_invalid_arg(k, acc, fmt);
  }
  throw new MelangeError("Assert_failure", {
    MEL_EXN_ID: "Assert_failure",
    _1: [
      "camlinternalFormat.cppo.ml",
      1626,
      39
    ]
  });
}
function make_from_fmtty(k, acc, fmtty, fmt) {
  if (
    /* tag */
    typeof fmtty === "number" || typeof fmtty === "string"
  ) {
    return make_invalid_arg(k, acc, fmt);
  }
  switch (fmtty.TAG) {
    case /* Char_ty */
    0:
      const rest = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest, fmt);
      };
    case /* String_ty */
    1:
      const rest$1 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$1, fmt);
      };
    case /* Int_ty */
    2:
      const rest$2 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$2, fmt);
      };
    case /* Int32_ty */
    3:
      const rest$3 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$3, fmt);
      };
    case /* Nativeint_ty */
    4:
      const rest$4 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$4, fmt);
      };
    case /* Int64_ty */
    5:
      const rest$5 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$5, fmt);
      };
    case /* Float_ty */
    6:
      const rest$6 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$6, fmt);
      };
    case /* Bool_ty */
    7:
      const rest$7 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$7, fmt);
      };
    case /* Format_arg_ty */
    8:
      const rest$8 = fmtty._1;
      return function(param) {
        return make_from_fmtty(k, acc, rest$8, fmt);
      };
    case /* Format_subst_ty */
    9:
      const rest$9 = fmtty._2;
      const ty = trans(symm(fmtty._0), fmtty._1);
      return function(param) {
        return make_from_fmtty(k, acc, concat_fmtty(ty, rest$9), fmt);
      };
    case /* Alpha_ty */
    10:
      const rest$10 = fmtty._0;
      return function(param, param$1) {
        return make_from_fmtty(k, acc, rest$10, fmt);
      };
    case /* Theta_ty */
    11:
      const rest$11 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$11, fmt);
      };
    case /* Any_ty */
    12:
      const rest$12 = fmtty._0;
      return function(param) {
        return make_from_fmtty(k, acc, rest$12, fmt);
      };
    case /* Reader_ty */
    13:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          1649,
          31
        ]
      });
    case /* Ignored_reader_ty */
    14:
      throw new MelangeError("Assert_failure", {
        MEL_EXN_ID: "Assert_failure",
        _1: [
          "camlinternalFormat.cppo.ml",
          1650,
          31
        ]
      });
  }
}
function make_invalid_arg(k, acc, fmt) {
  return make_printf(k, {
    TAG: (
      /* Acc_invalid_arg */
      8
    ),
    _0: acc,
    _1: "Printf: bad conversion %_"
  }, fmt);
}
function make_padding(k, acc, fmt, pad, trans2) {
  if (
    /* tag */
    typeof pad === "number" || typeof pad === "string"
  ) {
    return function(x) {
      const new_acc_1 = _1(trans2, x);
      const new_acc = {
        TAG: (
          /* Acc_data_string */
          4
        ),
        _0: acc,
        _1: new_acc_1
      };
      return make_printf(k, new_acc, fmt);
    };
  }
  if (pad.TAG === /* Lit_padding */
  0) {
    const width = pad._1;
    const padty = pad._0;
    return function(x) {
      const new_acc_1 = fix_padding(padty, width, _1(trans2, x));
      const new_acc = {
        TAG: (
          /* Acc_data_string */
          4
        ),
        _0: acc,
        _1: new_acc_1
      };
      return make_printf(k, new_acc, fmt);
    };
  }
  const padty$1 = pad._0;
  return function(w, x) {
    const new_acc_1 = fix_padding(padty$1, w, _1(trans2, x));
    const new_acc = {
      TAG: (
        /* Acc_data_string */
        4
      ),
      _0: acc,
      _1: new_acc_1
    };
    return make_printf(k, new_acc, fmt);
  };
}
function make_int_padding_precision(k, acc, fmt, pad, prec, trans2, iconv) {
  if (
    /* tag */
    typeof pad === "number" || typeof pad === "string"
  ) {
    if (
      /* tag */
      typeof prec === "number" || typeof prec === "string"
    ) {
      if (prec === /* No_precision */
      0) {
        return function(x) {
          const str = _2(trans2, iconv, x);
          return make_printf(k, {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: str
          }, fmt);
        };
      } else {
        return function(p2, x) {
          const str = fix_int_precision(p2, _2(trans2, iconv, x));
          return make_printf(k, {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: str
          }, fmt);
        };
      }
    }
    const p = prec._0;
    return function(x) {
      const str = fix_int_precision(p, _2(trans2, iconv, x));
      return make_printf(k, {
        TAG: (
          /* Acc_data_string */
          4
        ),
        _0: acc,
        _1: str
      }, fmt);
    };
  }
  if (pad.TAG === /* Lit_padding */
  0) {
    const w = pad._1;
    const padty = pad._0;
    if (
      /* tag */
      typeof prec === "number" || typeof prec === "string"
    ) {
      if (prec === /* No_precision */
      0) {
        return function(x) {
          const str = fix_padding(padty, w, _2(trans2, iconv, x));
          return make_printf(k, {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: str
          }, fmt);
        };
      } else {
        return function(p, x) {
          const str = fix_padding(padty, w, fix_int_precision(p, _2(trans2, iconv, x)));
          return make_printf(k, {
            TAG: (
              /* Acc_data_string */
              4
            ),
            _0: acc,
            _1: str
          }, fmt);
        };
      }
    }
    const p$1 = prec._0;
    return function(x) {
      const str = fix_padding(padty, w, fix_int_precision(p$1, _2(trans2, iconv, x)));
      return make_printf(k, {
        TAG: (
          /* Acc_data_string */
          4
        ),
        _0: acc,
        _1: str
      }, fmt);
    };
  }
  const padty$1 = pad._0;
  if (
    /* tag */
    typeof prec === "number" || typeof prec === "string"
  ) {
    if (prec === /* No_precision */
    0) {
      return function(w, x) {
        const str = fix_padding(padty$1, w, _2(trans2, iconv, x));
        return make_printf(k, {
          TAG: (
            /* Acc_data_string */
            4
          ),
          _0: acc,
          _1: str
        }, fmt);
      };
    } else {
      return function(w, p, x) {
        const str = fix_padding(padty$1, w, fix_int_precision(p, _2(trans2, iconv, x)));
        return make_printf(k, {
          TAG: (
            /* Acc_data_string */
            4
          ),
          _0: acc,
          _1: str
        }, fmt);
      };
    }
  }
  const p$2 = prec._0;
  return function(w, x) {
    const str = fix_padding(padty$1, w, fix_int_precision(p$2, _2(trans2, iconv, x)));
    return make_printf(k, {
      TAG: (
        /* Acc_data_string */
        4
      ),
      _0: acc,
      _1: str
    }, fmt);
  };
}
function make_custom(k, acc, rest, arity, f) {
  if (
    /* tag */
    typeof arity === "number" || typeof arity === "string"
  ) {
    return make_printf(k, {
      TAG: (
        /* Acc_data_string */
        4
      ),
      _0: acc,
      _1: f
    }, rest);
  }
  const arity$1 = arity._0;
  return function(x) {
    return make_custom(k, acc, rest, arity$1, _1(f, x));
  };
}
function strput_acc(b, _acc) {
  while (true) {
    const acc = _acc;
    let exit2 = 0;
    if (
      /* tag */
      typeof acc === "number" || typeof acc === "string"
    ) {
      return;
    }
    switch (acc.TAG) {
      case /* Acc_formatting_lit */
      0:
        const s = string_of_formatting_lit(acc._1);
        strput_acc(b, acc._0);
        return add_string(b, s);
      case /* Acc_formatting_gen */
      1:
        const acc$p = acc._1;
        const p = acc._0;
        if (acc$p.TAG === /* Acc_open_tag */
        0) {
          strput_acc(b, p);
          add_string(b, "@{");
          _acc = acc$p._0;
          continue;
        }
        strput_acc(b, p);
        add_string(b, "@[");
        _acc = acc$p._0;
        continue;
      case /* Acc_string_literal */
      2:
      case /* Acc_data_string */
      4:
        exit2 = 1;
        break;
      case /* Acc_char_literal */
      3:
      case /* Acc_data_char */
      5:
        exit2 = 2;
        break;
      case /* Acc_delay */
      6:
        strput_acc(b, acc._0);
        return add_string(b, _1(acc._1, void 0));
      case /* Acc_flush */
      7:
        _acc = acc._0;
        continue;
      case /* Acc_invalid_arg */
      8:
        strput_acc(b, acc._0);
        throw new MelangeError("Invalid_argument", {
          MEL_EXN_ID: "Invalid_argument",
          _1: acc._1
        });
    }
    switch (exit2) {
      case 1:
        strput_acc(b, acc._0);
        return add_string(b, acc._1);
      case 2:
        strput_acc(b, acc._0);
        return add_char(b, acc._1);
    }
  }
  ;
}

// node_modules/melange/printf.js
function ksprintf(k, param) {
  const k$p = function(acc) {
    const buf = create2(64);
    strput_acc(buf, acc);
    return _1(k, contents(buf));
  };
  return make_printf(
    k$p,
    /* End_of_acc */
    0,
    param._0
  );
}
function sprintf(fmt) {
  return ksprintf((function(s) {
    return s;
  }), fmt);
}

// node_modules/melange/printexc.js
var printers = make3(
  /* [] */
  0
);
var locfmt = {
  TAG: (
    /* Format */
    0
  ),
  _0: {
    TAG: (
      /* String_literal */
      11
    ),
    _0: 'File "',
    _1: {
      TAG: (
        /* String */
        2
      ),
      _0: (
        /* No_padding */
        0
      ),
      _1: {
        TAG: (
          /* String_literal */
          11
        ),
        _0: '", line ',
        _1: {
          TAG: (
            /* Int */
            4
          ),
          _0: (
            /* Int_d */
            0
          ),
          _1: (
            /* No_padding */
            0
          ),
          _2: (
            /* No_precision */
            0
          ),
          _3: {
            TAG: (
              /* String_literal */
              11
            ),
            _0: ", characters ",
            _1: {
              TAG: (
                /* Int */
                4
              ),
              _0: (
                /* Int_d */
                0
              ),
              _1: (
                /* No_padding */
                0
              ),
              _2: (
                /* No_precision */
                0
              ),
              _3: {
                TAG: (
                  /* Char_literal */
                  12
                ),
                _0: (
                  /* '-' */
                  45
                ),
                _1: {
                  TAG: (
                    /* Int */
                    4
                  ),
                  _0: (
                    /* Int_d */
                    0
                  ),
                  _1: (
                    /* No_padding */
                    0
                  ),
                  _2: (
                    /* No_precision */
                    0
                  ),
                  _3: {
                    TAG: (
                      /* String_literal */
                      11
                    ),
                    _0: ": ",
                    _1: {
                      TAG: (
                        /* String */
                        2
                      ),
                      _0: (
                        /* No_padding */
                        0
                      ),
                      _1: (
                        /* End_of_format */
                        0
                      )
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  _1: 'File "%s", line %d, characters %d-%d: %s'
};
var fields = (function(x) {
  var s = "";
  var index = 1;
  while ("_" + index in x) {
    s += x["_" + index];
    ++index;
  }
  if (index === 1) {
    return s;
  }
  return "(" + s + ")";
});
function use_printers(x) {
  let _param = get4(printers);
  while (true) {
    const param = _param;
    if (!param) {
      return;
    }
    const tl = param.tl;
    let s;
    try {
      s = _1(param.hd, x);
    } catch (exn) {
      _param = tl;
      continue;
    }
    if (s !== void 0) {
      return some(valFromOption(s));
    }
    _param = tl;
    continue;
  }
  ;
}
function to_string_default(x) {
  if (x.MEL_EXN_ID === Out_of_memory) {
    return "Out of memory";
  }
  if (x.MEL_EXN_ID === Stack_overflow) {
    return "Stack overflow";
  }
  if (x.MEL_EXN_ID === Match_failure) {
    const match = x._1;
    const $$char = match[2];
    return _5(sprintf(locfmt), match[0], match[1], $$char, $$char + 5 | 0, "Pattern matching failed");
  }
  if (x.MEL_EXN_ID === Assert_failure) {
    const match$1 = x._1;
    const $$char$1 = match$1[2];
    return _5(sprintf(locfmt), match$1[0], match$1[1], $$char$1, $$char$1 + 6 | 0, "Assertion failed");
  }
  if (x.MEL_EXN_ID === Undefined_recursive_module) {
    const match$2 = x._1;
    const $$char$2 = match$2[2];
    return _5(sprintf(locfmt), match$2[0], match$2[1], $$char$2, $$char$2 + 6 | 0, "Undefined recursive module");
  }
  const constructor = caml_exn_slot_name(x);
  return constructor + fields(x);
}
function to_string3(e) {
  const s = use_printers(e);
  if (s !== void 0) {
    return s;
  } else {
    return to_string_default(e);
  }
}

// node_modules/solid-ml-browser/reactive_core.js
var current_runtime = {
  contents: void 0
};
function get_runtime(param) {
  return current_runtime.contents;
}
function set_runtime(rt) {
  current_runtime.contents = rt;
}
function handle_error(exn, context) {
  console.error("solid-ml: Error in " + (context + (": " + to_string3(exn))));
}
var Backend_Browser = {
  get_runtime,
  set_runtime,
  handle_error
};
var R = Make(Backend_Browser);
var set_signal = R.write_typed_signal;
var peek_signal = R.peek_typed_signal;
function create_root(f) {
  const match = _1(R.get_runtime_opt, void 0);
  if (match !== void 0) {
    return _1(R.create_root, (function(dispose) {
      return [
        _1(f, void 0),
        dispose
      ];
    }));
  }
  const rt = create_runtime();
  current_runtime.contents = rt;
  return _1(R.create_root, (function(dispose) {
    return [
      _1(f, void 0),
      dispose
    ];
  }));
}
var create_signal = R.create_typed_signal;
var get_signal = R.read_typed_signal;
var create_effect = R.create_effect;
var create_effect_with_cleanup = R.create_effect_with_cleanup;
var untrack = R.untrack;
var create_memo = R.create_typed_memo;
var get_memo = R.read_typed_memo;
var peek_memo = R.peek_typed_memo;
var on_cleanup = R.on_cleanup;
var get_owner = R.get_owner;
var create_context = R.create_context;
var use_context = R.use_context;
var provide_context = R.provide_context;

// examples/ssr_api_app/client/client.js
function get_element(id) {
  return get_element_by_id($$document, id);
}
function query_selector2(sel) {
  return query_selector($$document, sel);
}
function query_selector_all2(sel) {
  return query_selector_all($$document, sel);
}
var fetch_json_raw = (function(url, onSuccess, onError) {
  fetch(url).then(function(resp) {
    return resp.json();
  }).then(function(data) {
    onSuccess(JSON.stringify(data));
  }).catch(function(err) {
    onError(err.message || "Fetch failed");
  });
});
var json_get_string = (function(json, key) {
  try {
    var obj = JSON.parse(json);
    return obj[key] || "";
  } catch (e) {
    return "";
  }
});
var json_get_int = (function(json, key) {
  try {
    var obj = JSON.parse(json);
    return obj[key] || 0;
  } catch (e) {
    return 0;
  }
});
var json_array_map = (function(json, fn) {
  try {
    var arr = JSON.parse(json);
    return arr.map(function(item) {
      return fn(JSON.stringify(item));
    });
  } catch (e) {
    return [];
  }
});
function parse_post(json) {
  return {
    id: json_get_int(json, "id"),
    user_id: json_get_int(json, "userId"),
    title: json_get_string(json, "title"),
    body: json_get_string(json, "body")
  };
}
function parse_comment(json) {
  return {
    id: json_get_int(json, "id"),
    post_id: json_get_int(json, "postId"),
    name: json_get_string(json, "name"),
    email: json_get_string(json, "email"),
    body: json_get_string(json, "body")
  };
}
function fetch_posts(on_success, on_error) {
  fetch_json_raw("/api/posts", (function(json) {
    _1(on_success, map(parse_post, json_array_map(json, (function(item) {
      return item;
    }))));
  }), on_error);
}
function fetch_post(id, on_success, on_error) {
  fetch_json_raw("/api/posts/" + String(id), (function(json) {
    _1(on_success, parse_post(json));
  }), on_error);
}
function fetch_comments(post_id, on_success, on_error) {
  fetch_json_raw("/api/posts/" + (String(post_id) + "/comments"), (function(json) {
    _1(on_success, map(parse_comment, json_array_map(json, (function(item) {
      return item;
    }))));
  }), on_error);
}
function html_escape(s) {
  const b = create2(s.length);
  iter3((function(c) {
    if (c === 34) {
      return add_string(b, "&quot;");
    }
    if (c < 60) {
      if (c !== 38) {
        return add_char(b, c);
      } else {
        return add_string(b, "&amp;");
      }
    }
    if (c >= 63) {
      return add_char(b, c);
    }
    switch (c) {
      case 60:
        return add_string(b, "&lt;");
      case 61:
        return add_char(b, c);
      case 62:
        return add_string(b, "&gt;");
    }
  }), s);
  return contents(b);
}
function render_post_card(post) {
  return '<div class="post-card">\n    <h3><a href="/posts/' + (String(post.id) + ('" data-link>' + (html_escape(post.title) + ("</a></h3>\n    <p>" + (html_escape(sub4(post.body, 0, caml_int_min(120, post.body.length))) + ('...</p>\n    <div class="meta">Post #' + (String(post.id) + (" by User #" + (String(post.user_id) + "</div>\n  </div>")))))))));
}
function render_posts_list(posts) {
  return concat2("\n", map(render_post_card, posts));
}
function render_comment(comment) {
  return '<div class="comment">\n    <div class="author">' + (html_escape(comment.name) + ('</div>\n    <div class="email">' + (html_escape(comment.email) + ('</div>\n    <div class="body">' + (html_escape(comment.body) + "</div>\n  </div>")))));
}
function render_comments(comments) {
  return concat2("\n", map(render_comment, comments));
}
function render_post_detail(post) {
  return "<h2>" + (html_escape(post.title) + ('</h2>\n  <div class="meta">Post #' + (String(post.id) + (" by User #" + (String(post.user_id) + ('</div>\n  <div class="body">' + (html_escape(post.body) + "</div>")))))));
}
function render_loading(param) {
  return '<div class="loading">Loading...</div>';
}
function render_error(msg) {
  return '<div class="error"><h2>Error</h2><p>' + (html_escape(msg) + "</p></div>");
}
var current_path = {
  contents: get_pathname()
};
function setup_links(param) {
  const links = query_selector_all($$document, "a[data-link], .post-card h3 a, .back-link, .nav-link");
  iter((function(link) {
    add_event_listener(link, "click", (function(evt) {
      const href = get_attribute(link, "href");
      if (href !== void 0 && href.length !== 0 && get(href, 0) === /* '/' */
      47) {
        prevent_default(evt);
        return navigate(href);
      }
    }));
  }), links);
}
function navigate(path) {
  if (path !== current_path.contents) {
    current_path.contents = path;
    push_state(path);
    return render_page(path);
  }
}
function render_page(path) {
  const app_el = get_element_by_id($$document, "app");
  if (app_el === void 0) {
    return;
  }
  const app_el$1 = valFromOption(app_el);
  if (!(path.length > 7 && sub4(path, 0, 7) === "/posts/")) {
    if (path === "/") {
      return render_posts_page(app_el$1);
    } else {
      return set_inner_html(app_el$1, render_error("Page not found: " + path));
    }
  }
  const id_str = sub4(path, 7, path.length - 7 | 0);
  const id = int_of_string_opt(id_str);
  if (id !== void 0) {
    return render_post_page(app_el$1, id);
  } else {
    return set_inner_html(app_el$1, render_error("Invalid post ID"));
  }
}
function render_posts_page(app_el) {
  set_inner_html(app_el, '<h2>Recent Posts</h2>\n    <p>Click on a post to view details and comments.</p>\n    <div id="posts-list"><div class="loading">Loading...</div></div>\n    <div id="hydration-status" class="hydration-status active">\n      Client-side navigation active.\n    </div>');
  fetch_posts((function(posts) {
    const el = get_element_by_id($$document, "posts-list");
    if (el !== void 0) {
      set_inner_html(valFromOption(el), render_posts_list(posts));
      return setup_links();
    }
  }), (function(err) {
    const el = get_element_by_id($$document, "posts-list");
    if (el !== void 0) {
      return set_inner_html(valFromOption(el), render_error("Failed to load posts: " + err));
    }
  }));
}
function render_post_page(app_el, post_id) {
  set_inner_html(app_el, '<a href="/" class="back-link" data-link>\xE2\x86\x90 Back to all posts</a>\n    <div class="post-detail" id="post-detail"><div class="loading">Loading...</div></div>\n    <div class="comments" id="comments-section">\n      <h3>Comments</h3>\n      <div id="comments-list"><div class="loading">Loading...</div></div>\n    </div>\n    <div id="hydration-status" class="hydration-status active">\n      Client-side navigation active.\n    </div>');
  setup_links();
  fetch_post(post_id, (function(post) {
    const el = get_element_by_id($$document, "post-detail");
    if (el !== void 0) {
      return set_inner_html(valFromOption(el), render_post_detail(post));
    }
  }), (function(err) {
    const el = get_element_by_id($$document, "post-detail");
    if (el !== void 0) {
      return set_inner_html(valFromOption(el), render_error("Failed to load post: " + err));
    }
  }));
  fetch_comments(post_id, (function(comments) {
    const el = get_element_by_id($$document, "comments-section");
    if (el !== void 0) {
      return set_inner_html(valFromOption(el), "<h3>Comments (" + (String(length(comments)) + (')</h3>\n          <div id="comments-list">' + (render_comments(comments) + "</div>"))));
    }
  }), (function(err) {
    const el = get_element_by_id($$document, "comments-list");
    if (el !== void 0) {
      return set_inner_html(valFromOption(el), render_error("Failed to load comments: " + err));
    }
  }));
}
function setup_navigation(param) {
  on_popstate(function(_evt) {
    const path = get_pathname();
    current_path.contents = path;
    render_page(path);
  });
  setup_links();
}
create_root(function(param) {
  const path = get_pathname();
  log("Hydrating page: " + path);
  setup_navigation();
  const el = get_element_by_id($$document, "hydration-status");
  if (el !== void 0) {
    add_class(valFromOption(el), "active");
  }
  log("Hydration complete!");
});
export {
  current_path,
  fetch_comments,
  fetch_json_raw,
  fetch_post,
  fetch_posts,
  get_element,
  html_escape,
  json_array_map,
  json_get_int,
  json_get_string,
  navigate,
  parse_comment,
  parse_post,
  query_selector2 as query_selector,
  query_selector_all2 as query_selector_all,
  render_comment,
  render_comments,
  render_error,
  render_loading,
  render_page,
  render_post_card,
  render_post_detail,
  render_post_page,
  render_posts_list,
  render_posts_page,
  setup_links,
  setup_navigation
};
