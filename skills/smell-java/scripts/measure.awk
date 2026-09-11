# measure.awk - counted evidence for /smell-java (Java only, POSIX awk, no parser).
# Heuristic brace and regex counting: lambdas and anonymous classes add one nesting level,
# a nested `if` restarts the surrounding if-chain count, text blocks are not stripped.
# Every number is a count the scout can verify at the reported line.

BEGIN {
  depth = 0; inBlock = 0
  inMeth = 0; pendSig = ""; pendLine = 0
  nMeth = 0; nDeps = 0; nWild = 0; nConst = 0; nRest = 0; nValue = 0
  hasEntity = 0; hasData = 0; hasSetter = 0; hasRestCtl = 0; hasConstIface = 0
  pendTx = 0; pendAuto = 0; pendAnn = 0
  nSw = 0; chainArms = 0; chainLine = 0; chainCond = ""; chainMeth = ""
  m_format = 0; m_toList = 0; m_asList = 0; m_optget = 0; m_date = 0; m_sbuf = 0; m_swstmt = 0; m_indexloop = 0
  restFirst = 0
}

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function strip(line,   s, r) {
  s = line
  if (inBlock) {
    r = index(s, "*/")
    if (r == 0) return ""
    s = substr(s, r + 2); inBlock = 0
  }
  gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
  gsub(/'([^'\\]|\\.)*'/, "''", s)
  while ((r = index(s, "/*")) > 0) {
    if (index(substr(s, r), "*/") > 0) {
      s = substr(s, 1, r - 1) substr(s, r + index(substr(s, r), "*/") + 1)
    } else { s = substr(s, 1, r - 1); inBlock = 1; break }
  }
  sub(/\/\/.*$/, "", s)
  return s
}

function countParams(sig,   p, q, inner, n, i, c, lvl, booleans) {
  p = index(sig, "("); if (p == 0) return 0
  inner = substr(sig, p + 1)
  # cut at the matching ')'
  lvl = 1; q = 0
  for (i = 1; i <= length(inner); i++) {
    c = substr(inner, i, 1)
    if (c == "(") lvl++
    else if (c == ")") { lvl--; if (lvl == 0) { q = i; break } }
  }
  if (q > 0) inner = substr(inner, 1, q - 1)
  while (match(inner, /<[^<>]*>/)) inner = substr(inner, 1, RSTART - 1) substr(inner, RSTART + RLENGTH)
  inner = trim(inner)
  if (inner == "") return 0
  n = 1
  for (i = 1; i <= length(inner); i++) if (substr(inner, i, 1) == ",") n++
  booleans = 0
  q = inner
  while (match(q, /(^|[ ,])(boolean|Boolean)[ \t]/)) { booleans++; q = substr(q, RSTART + RLENGTH) }
  mBooleans = booleans
  if (inner ~ /Optional</) optParam = 1; else optParam = 0
  return n
}

# text after the first "(" up to its matching ")"
function parenExpr(s,   p, i, c, lvl, inner) {
  p = index(s, "("); if (p == 0) return s
  inner = substr(s, p + 1); lvl = 1
  for (i = 1; i <= length(inner); i++) {
    c = substr(inner, i, 1)
    if (c == "(") lvl++
    else if (c == ")") { lvl--; if (lvl == 0) return substr(inner, 1, i - 1) }
  }
  return inner
}

function flushChain() {
  if (chainArms >= 3) printf "IFCHAIN @%d arms=%d on=%s in=%s\n", chainLine, chainArms, chainCond, chainMeth
  chainArms = 0; chainLine = 0; chainCond = ""
}

function startMethod(sig, line,   name) {
  inMeth = 1; mStart = line; mDepth = depth; mMaxNest = 0; mNulls = 0; mCopies = 0
  mCatch = 0; mCatchResp = 0
  name = sig
  sub(/[ \t]*\(.*$/, "", name); sub(/^.*[ \t]/, "", name)
  mName = name
  mParams = countParams(sig)
  mOptParam = optParam
  if (pendTx && sig ~ /^[ \t]*private[ \t]/) printf "SPRING TX_PRIVATE @%d %s\n", line, name
  if (pendTx && hasRestCtl) printf "SPRING TX_ON_CONTROLLER @%d %s\n", line, name
  if (mOptParam) printf "OPTIONAL_PARAM @%d %s\n", line, name
  pendTx = 0
  nMeth++
}

function endMethod(line,   len) {
  len = line - mStart + 1
  # nest: catalogue scale, method body = 1
  printf "METHOD %s@%d lines=%d params=%d booleans=%d nest=%d nulls=%d\n", mName, mStart, len, mParams, mBooleans, mMaxNest + 1, mNulls
  if (mName ~ /^(to|from|map)([A-Z]|$)/ && mCopies > 0) printf "MAPPER %s@%d copies=%d\n", mName, mStart, mCopies
  if (mCatchResp) printf "SPRING CATCH_RESPONSEENTITY @%d %s\n", mCatchResp, mName
  inMeth = 0
  flushChain()
}

{
  raw = $0
  s = strip(raw)
  t = trim(s)
  if (t == "") next

  # ---- file-level facts
  if (t ~ /^import .*\*;/) nWild++
  if (t ~ /^@Entity/) hasEntity = 1
  if (t ~ /^@Data/) hasData = 1
  if (t ~ /^@Setter/ && depth == 0) hasSetter = 1
  if (t ~ /^@RestController/) hasRestCtl = 1
  if (t ~ /implements [A-Za-z0-9_, ]*Constants/) hasConstIface = 1
  if (t ~ /public static final (int|long|String|short) /) nConst++
  if (t ~ /@Value\("\$\{/) nValue++
  if (t ~ /RestTemplate/) { nRest++; if (!restFirst) restFirst = NR }
  if (t ~ /String\.format\(/) m_format++
  if (t ~ /Collectors\.toList\(\)/) m_toList++
  if (t ~ /Arrays\.asList\(/) m_asList++
  if (t ~ /\.isPresent\(\)|Optional[^;]*\.get\(\)/) m_optget++
  if (t ~ /new Date\(\)|System\.currentTimeMillis\(\)|Calendar\.getInstance\(\)/) m_date++
  if (t ~ /StringBuffer/) m_sbuf++
  if (t ~ /for[ \t]*\([ \t]*int [a-z]+[ \t]*=[ \t]*0;/) m_indexloop++

  # ---- pending annotations
  if (t ~ /^@Transactional/) { pendTx = 1; pendAnn = 1; if (hasRestCtl && depth == 0) printf "SPRING TX_ON_CONTROLLER @%d class\n", NR }
  if (t ~ /^@Autowired/) { pendAuto = 1; pendAnn = 1; next }
  if (pendAuto) {
    if (t ~ /;$/ && t !~ /\(/) printf "SPRING FIELD_INJECTION @%d %s\n", NR, t
    pendAuto = 0
  }
  if (t ~ /^@/ && t !~ /\)[ \t]*\{/) { next }

  # ---- class-body facts (depth 1 = inside the top-level type)
  if (!inMeth && depth == 1) {
    if (t ~ /^private final .*;$/ && t !~ /\(/ && t !~ /static/) nDeps++
    if (t ~ /^private (final )?Optional</) printf "OPTIONAL_FIELD @%d %s\n", NR, t
  }

  # ---- method start detection
  isType = (t ~ /^(public |protected |private |static |final |abstract |sealed |non-sealed )*(class|interface|enum|record) /)
  cand = 0
  if (!inMeth && !isType && depth >= 1 && pendSig == "") {
    if (t ~ /^(public|protected|private|static|final|synchronized|abstract|default|native|<)/ || t ~ /^[A-Za-z_][A-Za-z0-9_<>\[\],.?]*[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) {
      if (t ~ /^[A-Za-z_<][A-Za-z0-9_<>\[\],.? \t]*[ \t][A-Za-z_][A-Za-z0-9_]*[ \t]*\(/ && t !~ /^(if|for|while|switch|catch|synchronized|return|new|else|try|do|throw|case|assert|yield)[ \t(]/) {
        pre = t; sub(/\(.*$/, "", pre)
        if (pre !~ /=/ && pre !~ /\./) cand = 1
      }
    }
  }
  if (cand) {
    if (t ~ /;[ \t]*$/ && t !~ /\{/) cand = 0           # abstract / interface method
    else if (t ~ /\{[ \t]*$/ || t ~ /\)[ \t]*(throws [A-Za-z0-9_., ]+)?[ \t]*\{/) { startMethod(t, NR) }
    else { pendSig = t; pendLine = NR; cand = 0 }
  } else if (pendSig != "") {
    pendSig = pendSig " " t
    if (t ~ /;/ && t !~ /\{/) { pendSig = "" }
    else if (t ~ /\{/) { startMethod(pendSig, pendLine); pendSig = "" }
  }

  # ---- inside a method: conditionals, nulls, copies, catch
  if (inMeth) {
    if (t ~ /(^|[^A-Za-z_])switch[ \t]*\(/) {
      nSw++; swLine[nSw] = NR; swDepth[nSw] = depth; swArms[nSw] = 0
      e = t; sub(/^.*switch[ \t]*/, "", e); swExpr[nSw] = substr(parenExpr(e), 1, 40); swMeth[nSw] = mName
    }
    if (nSw > 0 && t ~ /^(case|default)([ \t]|:|$)/) swArms[nSw]++
    if (t ~ /^if[ \t]*\(/) { flushChain(); chainArms = 1; chainLine = NR; chainMeth = mName; c = t; sub(/^if[ \t]*/, "", c); chainCond = substr(parenExpr(c), 1, 40) }
    else if (t ~ /else[ \t]+if[ \t]*\(/) { if (chainArms == 0) { chainLine = NR; chainMeth = mName; chainArms = 1 } chainArms++ }
    else if (t ~ /(^|\})[ \t]*else[ \t]*\{?[ \t]*$/) { chainArms++; flushChain() }
    n = t; while (match(n, /[!=]= *null/)) { mNulls++; n = substr(n, RSTART + RLENGTH) }
    n = t; while (match(n, /\.get[A-Z][A-Za-z0-9_]*\(\)/)) { mCopies++; n = substr(n, RSTART + RLENGTH) }
    if (t ~ /\.get[A-Za-z0-9_]*\(\)\.get[A-Za-z0-9_]*\(\)\.get[A-Za-z0-9_]*\(\)/) printf "CHAIN @%d %s\n", NR, substr(t, 1, 60)
    n = t; while (match(n, /[A-Za-z_][A-Za-z0-9_]* +instanceof +/)) { v = substr(n, RSTART, RLENGTH); sub(/ +instanceof.*/, "", v); io[v]++; if (!(v in ioFirst)) ioFirst[v] = NR; n = substr(n, RSTART + RLENGTH) }
    if (t ~ /catch[ \t]*\(/) mCatch = 1
    if (mCatch && !mCatchResp && t ~ /ResponseEntity|HttpStatus\./) mCatchResp = NR
    if (t ~ /(^|[^A-Za-z_])switch[ \t]*\(/ && t !~ /=[ \t]*switch|return[ \t]+switch|yield/) m_swstmt++
  }

  # ---- brace tracking
  o = gsub(/\{/, "{", s); cl = gsub(/\}/, "}", s)
  for (i = 1; i <= length(s); i++) {
    ch = substr(s, i, 1)
    if (ch == "{") { depth++; if (inMeth) { nest = depth - mDepth - 1; if (nest > mMaxNest) mMaxNest = nest } }
    else if (ch == "}") {
      depth--
      while (nSw > 0 && depth == swDepth[nSw]) {
        printf "SWITCH @%d arms=%d on=%s in=%s\n", swLine[nSw], swArms[nSw], swExpr[nSw], swMeth[nSw]; nSw--
      }
      if (inMeth && depth == mDepth) endMethod(NR)
    }
  }
}

END {
  if (inMeth) endMethod(NR)
  for (v in io) if (io[v] >= 2) printf "INSTANCEOF var=%s n=%d first@%d\n", v, io[v], ioFirst[v]
  if (hasEntity && hasData) printf "SPRING DATA_ON_ENTITY\n"
  if (hasEntity && hasSetter) printf "SPRING SETTER_ON_ENTITY\n"
  if (nRest) printf "SPRING RESTTEMPLATE n=%d first@%d\n", nRest, restFirst
  if (nValue) printf "SPRING VALUE_PLACEHOLDERS n=%d\n", nValue
  if (hasConstIface) printf "J2 CONSTANTS_INTERFACE\n"
  if (nConst >= 3) printf "J3 CONSTANT_GROUP n=%d\n", nConst
  if (nWild >= 2) printf "J1 WILDCARD_IMPORTS n=%d\n", nWild
  printf "MODERN String.format=%d Collectors.toList=%d Arrays.asList=%d Optional.get/isPresent=%d legacy_time=%d StringBuffer=%d switch_statements=%d index_loops=%d\n", m_format, m_toList, m_asList, m_optget, m_date, m_sbuf, m_swstmt, m_indexloop
  printf "FILE %s lines=%d methods=%d private_final_deps=%d\n", FILE, NR, nMeth, nDeps
}
