ObjC.import('Cocoa')
ObjC.import('stdlib')
ObjC.import('CoreGraphics')

var isOn = false
var durationMin = 0
var jiggleMin = 10
var startAtLogin = false
var startedAt = null
var lastJiggle = 0
var caffeinateTask = null
var statusItem = null
var delegate = null
var ticker = null
var didStart = false

var defaults = $.NSUserDefaults.standardUserDefaults
if (defaults.boolForKey('stayAwakeInit')) {
  durationMin = defaults.integerForKey('durationMinutes')
  jiggleMin = defaults.integerForKey('jiggleMinutes')
  startAtLogin = defaults.boolForKey('startAtLogin')
}

function log(msg) {
  try {
    var line = new Date().toISOString() + ' ' + msg + '\n'
    var path = $.NSHomeDirectory().js + '/Library/Logs/StayAwake.log'
    var existing = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null)
    var body = (existing && !existing.isNil && existing.isNil()) ? line : (existing.js || '') + line
    $.NSString.stringWithString(body).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)
  } catch (e) {}
}

ObjC.registerSubclass({
  name: 'StayAwakeDelegate',
  superclass: 'NSObject',
  methods: {
    'toggle:': {
      types: ['void', ['id']],
      implementation: function () { setOn(!isOn) },
    },
    'setDuration:': {
      types: ['void', ['id']],
      implementation: function (sender) {
        durationMin = sender.tag
        defaults.setIntegerForKey(durationMin, 'durationMinutes')
        defaults.setBoolForKey(true, 'stayAwakeInit')
        rebuildMenu()
      },
    },
    'setJiggle:': {
      types: ['void', ['id']],
      implementation: function (sender) {
        jiggleMin = sender.tag
        defaults.setIntegerForKey(jiggleMin, 'jiggleMinutes')
        defaults.setBoolForKey(true, 'stayAwakeInit')
        lastJiggle = Date.now()
        rebuildMenu()
      },
    },
    'toggleLogin:': {
      types: ['void', ['id']],
      implementation: function () { toggleLogin() },
    },
    'tick:': {
      types: ['void', ['id']],
      implementation: function () { onTick() },
    },
    'quit:': {
      types: ['void', ['id']],
      implementation: function (sender) {
        stopCaffeinate()
        defaults.setBoolForKey(false, 'isOn')
        $.NSApp.terminate(sender)
      },
    },
  },
})

function setButtonIcon() {
  if (!statusItem) return
  var button = statusItem.button
  try { button.image = null } catch (e) {}
  button.title = isOn ? 'Awake' : 'Awake'
  button.toolTip = isOn ? 'Stay Awake is on — click to turn off' : 'Stay Awake is off — click to turn on'
}

function makeItem(title, selector, tag, checked) {
  var item = $.NSMenuItem.alloc.init
  item.title = title
  item.action = $.NSSelectorFromString(selector)
  item.target = delegate
  if (typeof tag === 'number') item.tag = tag
  item.state = checked ? $.NSOnState : $.NSOffState
  item.enabled = true
  return item
}

function makeLabel(title) {
  var item = $.NSMenuItem.alloc.init
  item.title = title
  item.enabled = false
  return item
}

function elapsedLabel() {
  if (!isOn || !startedAt) return 'Off'
  var s = Math.floor((Date.now() - startedAt) / 1000)
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  if (h > 0) return 'Awake for ' + h + 'h ' + m + 'm'
  if (m > 0) return 'Awake for ' + m + ' min'
  return 'Awake for ' + s + 's'
}

function rebuildMenu() {
  var menu = $.NSMenu.alloc.init
  menu.autoenablesItems = false
  menu.addItem(makeItem(isOn ? 'Turn Off' : 'Turn On', 'toggle:', 0, false))
  if (isOn) menu.addItem(makeLabel(elapsedLabel()))
  menu.addItem($.NSMenuItem.separatorItem)
  menu.addItem(makeLabel('Keep Mac awake'))
  menu.addItem(makeItem('Until I turn it off', 'setDuration:', 0, durationMin === 0))
  menu.addItem(makeItem('30 minutes', 'setDuration:', 30, durationMin === 30))
  menu.addItem(makeItem('1 hour', 'setDuration:', 60, durationMin === 60))
  menu.addItem(makeItem('3 hours', 'setDuration:', 180, durationMin === 180))
  menu.addItem(makeItem('8 hours', 'setDuration:', 480, durationMin === 480))
  menu.addItem($.NSMenuItem.separatorItem)
  menu.addItem(makeLabel('Move cursor'))
  menu.addItem(makeItem('Off', 'setJiggle:', 0, jiggleMin === 0))
  menu.addItem(makeItem('Every 5 minutes', 'setJiggle:', 5, jiggleMin === 5))
  menu.addItem(makeItem('Every 10 minutes', 'setJiggle:', 10, jiggleMin === 10))
  menu.addItem(makeItem('Every 15 minutes', 'setJiggle:', 15, jiggleMin === 15))
  menu.addItem($.NSMenuItem.separatorItem)
  menu.addItem(makeItem(startAtLogin ? 'Start at login ✓' : 'Start at login', 'toggleLogin:', 0, startAtLogin))
  menu.addItem($.NSMenuItem.separatorItem)
  menu.addItem(makeItem('Quit Stay Awake', 'quit:', 0, false))
  statusItem.menu = menu
}

function startCaffeinate() {
  stopCaffeinate()
  var task = $.NSTask.alloc.init
  task.launchPath = '/usr/bin/caffeinate'
  task.arguments = ['-diu', '-w', String($.NSProcessInfo.processInfo.processIdentifier)]
  task.launch
  caffeinateTask = task
}

function stopCaffeinate() {
  if (caffeinateTask) {
    try { caffeinateTask.terminate } catch (e) {}
    caffeinateTask = null
  }
}

function setOn(on) {
  if (on) {
    startCaffeinate()
    isOn = true
    startedAt = Date.now()
    lastJiggle = Date.now()
    defaults.setBoolForKey(true, 'isOn')
  } else {
    stopCaffeinate()
    isOn = false
    startedAt = null
    defaults.setBoolForKey(false, 'isOn')
  }
  setButtonIcon()
  rebuildMenu()
}

function jiggleCursor() {
  try {
    var loc = $.NSEvent.mouseLocation
    var screens = $.NSScreen.screens
    var maxY = 0
    for (var i = 0; i < screens.count; i++) {
      var f = screens.objectAtIndex(i).frame
      var top = f.origin.y + f.size.height
      if (top > maxY) maxY = top
    }
    var x = loc.x
    var y = maxY - loc.y
    var e1 = $.CGEventCreateMouseEvent(null, $.kCGEventMouseMoved, { x: x + 1, y: y }, 0)
    $.CGEventPost($.kCGHIDEventTap, e1)
    var e2 = $.CGEventCreateMouseEvent(null, $.kCGEventMouseMoved, { x: x, y: y }, 0)
    $.CGEventPost($.kCGHIDEventTap, e2)
  } catch (e) {}
}

function onTick() {
  if (!isOn) {
    rebuildMenu()
    return
  }
  if (durationMin > 0 && startedAt) {
    if (Date.now() - startedAt >= durationMin * 60000) {
      setOn(false)
      return
    }
  }
  if (jiggleMin > 0 && Date.now() - lastJiggle >= jiggleMin * 60000) {
    jiggleCursor()
    lastJiggle = Date.now()
  }
  rebuildMenu()
}

function bundlePath() {
  var home = $.NSProcessInfo.processInfo.environment.objectForKey('HOME')
  if (home) return home.js + '/Library/Application Support/StayAwake/StayAwake.js'
  return ''
}

function toggleLogin() {
  var next = !startAtLogin
  startAtLogin = next
  defaults.setBoolForKey(startAtLogin, 'startAtLogin')
  defaults.setBoolForKey(true, 'stayAwakeInit')
  rebuildMenu()
}

function startStayAwake() {
  if (didStart) return
  didStart = true
  log('starting')
  delegate = $.StayAwakeDelegate.alloc.init
  var nsapp = $.NSApplication.sharedApplication
  nsapp.setActivationPolicy($.NSApplicationActivationPolicyAccessory)
  statusItem = $.NSStatusBar.systemStatusBar.statusItemWithLength(-1)
  setButtonIcon()
  rebuildMenu()
  ticker = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    15, delegate, 'tick:', null, true
  )
  $.NSRunLoop.mainRunLoop.addTimerForMode(ticker, $.NSRunLoopCommonModes)
  if (defaults.boolForKey('isOn')) setOn(true)
  log('menu bar item created')
  nsapp.run()
}

function run() {
  startStayAwake()
}

startStayAwake()
