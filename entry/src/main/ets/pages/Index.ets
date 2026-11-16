import { common } from '@kit.AbilityKit';
import { displaySync } from '@kit.ArkGraphics2D';
import { Constants } from '../common/Constants';
import { LogEntry, Logger, LogLevel } from '../common/Logger';
import { AccelFilter } from '../input/AccelFilter';
import { Deadzone } from '../input/Deadzone';
import { GestureAccumulator, ObjectState } from '../input/GestureAccumulator';
import { InputArbiter, InputSource } from '../input/InputArbiter';
import { InputLifecycle, TiltSource } from '../input/InputLifecycle';
import { InputSettings } from '../input/InputSettings';
import { Vec2 } from '../input/Vec2';

const ROOT_ID: string = 'root';
const CHART_WIDTH: number = 160;
const CHART_HEIGHT: number = 64;

@Component
struct StepperRow {
  @Prop label: Resource;
  @Prop value: string;
  onMinus: () => void = () => {};
  onPlus: () => void = () => {};

  build() {
    Row({ space: 4 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor('#C7C7CC')
        .layoutWeight(1)
      Button('−')
        .width(30)
        .height(30)
        .fontSize(16)
        .backgroundColor($r('app.color.card'))
        .onClick(() => this.onMinus())
      Text(this.value)
        .width(36)
        .fontSize(14)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
      Button('+')
        .width(30)
        .height(30)
        .fontSize(16)
        .backgroundColor($r('app.color.card'))
        .onClick(() => this.onPlus())
    }
    .width('80%')
    .height(36)
  }
}

@Component
struct ToggleRow {
  @Prop label: Resource;
  @Prop isOn: boolean;
  onToggle: (isOn: boolean) => void = () => {};

  build() {
    Row() {
      Text(this.label)
        .fontSize(13)
        .fontColor(Color.White)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor($r('app.color.success'))
        .onChange((isOn: boolean) => this.onToggle(isOn))
    }
    .width('80%')
    .height(40)
  }
}

@Entry
@Component
struct Index {
  @State objectState: ObjectState = new ObjectState();
  @State source: InputSource = InputSource.IDLE;
  @State settings: InputSettings = new InputSettings();
  @State tiltSource: TiltSource = TiltSource.OFF;
  @State subscriptions: number = 0;
  @State frameCallbackOn: boolean = false;
  @State showPanel: boolean = false;
  @State simulate: boolean = false;
  @State simX: number = 0;
  @State simY: number = 0;
  @State simJitter: boolean = true;
  @State chartRaw: number[][] = [];
  @State chartFiltered: number[][] = [];
  @State logs: LogEntry[] = [];

  private context?: common.UIAbilityContext;
  private accumulator: GestureAccumulator = new GestureAccumulator();
  private arbiter: InputArbiter = new InputArbiter();
  private filter: AccelFilter = new AccelFilter(Constants.DEFAULT_ALPHA);
  private lifecycle: InputLifecycle = new InputLifecycle((raw: Vec2) => this.onAccel(raw),
    (message: string, level: LogLevel) => this.addLog(message, level));
  private sync?: displaySync.DisplaySync;
  private arenaRadius: number = 0;
  private tiltVelocity: Vec2 = new Vec2(0, 0);
  private tiltMoving: boolean = false;
  private lastFrameTimestamp: number = 0;
  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private rawHistory: number[] = [];
  private filteredHistory: number[] = [];
  private chartTimerId: number = -1;
  private visible: boolean = false;
  private crownSeen: boolean = false;

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.applySettings(InputSettings.load(this.context), false);
  }

  onPageShow(): void {
    this.visible = true;
    this.crownSeen = false;
    this.startInputs();
  }

  onPageHide(): void {
    this.visible = false;
    this.stopInputs();
    this.addLog('Hidden: sensor and frame callback stopped, input reset');
  }

  aboutToDisappear(): void {
    this.visible = false;
    this.stopInputs();
  }

  // ---------- Lifecycle ----------

  private startInputs(): void {
    this.tiltSource = this.lifecycle.start(this.simulate);
    this.subscriptions = this.lifecycle.subscriptions();
    this.lastFrameTimestamp = 0;
    try {
      const sync = displaySync.create();
      sync.setExpectedFrameRateRange({ min: 30, max: 60, expected: 60 });
      sync.on('frame', (info: displaySync.IntervalInfo) => this.onFrame(info));
      sync.start();
      this.sync = sync;
      this.frameCallbackOn = true;
    } catch (err) {
      this.addLog(`displaySync failed: ${JSON.stringify(err)}`, LogLevel.ERROR);
    }
  }

  private stopInputs(): void {
    this.lifecycle.stop();
    this.subscriptions = this.lifecycle.subscriptions();
    this.tiltSource = TiltSource.OFF;
    if (this.sync !== undefined) {
      this.sync.stop();
      this.sync.off('frame');
      this.sync = undefined;
    }
    this.frameCallbackOn = false;
    this.stopChart();
    // Nothing collected before the pause may move the object after it.
    this.accumulator.reset();
    this.arbiter.reset();
    this.filter.reset();
    this.tiltVelocity = new Vec2(0, 0);
    this.tiltMoving = false;
    this.source = InputSource.IDLE;
  }

  // ---------- Input ----------

  private onAccel(raw: Vec2): void {
    const filtered = this.filter.update(raw);
    const live = Deadzone.apply(filtered, this.settings.deadzone);
    // Device x points right and y points up; screen y points down.
    this.tiltVelocity = new Vec2(-live.x * Constants.TILT_GAIN, live.y * Constants.TILT_GAIN);
    this.tiltMoving = live.length() > 0;
    this.pushHistory(raw.x, live.x);
  }

  /** Runs once per display frame: every input collected since the last frame is applied here. */
  private onFrame(info: displaySync.IntervalInfo): void {
    const frameMs = this.lastFrameTimestamp === 0 ? 16.67 : (info.timestamp - this.lastFrameTimestamp) / 1000000;
    this.lastFrameTimestamp = info.timestamp;
    const now = Date.now();
    const tilt = this.arbiter.tiltAllowed(now) ? this.tiltVelocity : Vec2.ZERO;
    const next = this.accumulator.applyFrame(this.objectState, frameMs, tilt, this.arenaRadius);
    if (!next.equals(this.objectState)) {
      this.objectState = next;
    }
    const source = this.arbiter.source(now, this.tiltMoving);
    if (source !== this.source) {
      this.source = source;
    }
  }

  private onPanStart(): void {
    this.arbiter.touchStart();
    this.accumulator.stopInertia();
    this.lastPanX = 0;
    this.lastPanY = 0;
  }

  private onPanUpdate(event: GestureEvent): void {
    // offsetX/Y are totals since the start of the pan: add only the new part.
    this.accumulator.addPan(event.offsetX - this.lastPanX, event.offsetY - this.lastPanY);
    this.lastPanX = event.offsetX;
    this.lastPanY = event.offsetY;
  }

  private onPanEnd(event: GestureEvent | undefined): void {
    this.arbiter.touchEnd(Date.now());
    if (event !== undefined && this.settings.inertia) {
      this.accumulator.startInertia(event.velocityX * this.settings.sensitivity,
        event.velocityY * this.settings.sensitivity);
    }
  }

  /**
   * Crown events go to the focused component and then up to its parents.
   * The handler is on the page root, so it gets the events from any focused
   * child. While the settings panel is open, the panel scrolls instead.
   */
  private onCrown(event: CrownEvent): void {
    if (this.showPanel) {
      return;
    }
    event.stopPropagation();
    if (!this.crownSeen) {
      this.crownSeen = true;
      this.addLog('Digital crown input received');
    }
    if (event.action === CrownAction.UPDATE) {
      this.accumulator.addCrown(event.degree);
      this.arbiter.crown(Date.now());
    }
  }

  // ---------- Settings ----------

  private applySettings(settings: InputSettings, save: boolean): void {
    this.settings = settings;
    this.filter.setAlpha(settings.alpha);
    this.accumulator.sensitivity = settings.sensitivity;
    if (save && this.context !== undefined) {
      settings.save(this.context);
    }
  }

  private changeSettings(change: (settings: InputSettings) => void): void {
    const next = this.settings.copy();
    change(next);
    next.deadzone = Math.min(Math.max(InputSettings.round(next.deadzone, Constants.DEADZONE_STEP),
      Constants.DEADZONE_MIN), Constants.DEADZONE_MAX);
    next.alpha = Math.min(Math.max(InputSettings.round(next.alpha, Constants.ALPHA_STEP), Constants.ALPHA_MIN),
      Constants.ALPHA_MAX);
    next.sensitivity = Math.min(Math.max(next.sensitivity, Constants.SENSITIVITY_MIN), Constants.SENSITIVITY_MAX);
    this.applySettings(next, true);
  }

  private onSimChange(isOn: boolean): void {
    this.simulate = isOn;
    this.addLog(`Simulated tilt ${isOn ? 'ON' : 'OFF'}`);
    if (this.visible) {
      this.stopInputs();
      this.startInputs();
    }
  }

  private openPanel(): void {
    this.showPanel = true;
    this.startChart();
  }

  private closePanel(): void {
    this.showPanel = false;
    this.stopChart();
    this.focusRoot();
  }

  /** Puts the focus back in the page, so that crown events reach the root handler. */
  private focusRoot(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(ROOT_ID);
    } catch (err) {
      this.addLog(`Focus request failed: ${JSON.stringify(err)}`, LogLevel.WARN);
    }
  }

  private centerObject(): void {
    this.accumulator.reset();
    const state = new ObjectState();
    state.zoom = this.objectState.zoom;
    this.objectState = state;
  }

  // ---------- Chart ----------

  private pushHistory(raw: number, filtered: number): void {
    this.rawHistory.push(raw);
    this.filteredHistory.push(filtered);
    if (this.rawHistory.length > Constants.CHART_POINTS) {
      this.rawHistory.shift();
      this.filteredHistory.shift();
    }
  }

  private startChart(): void {
    this.stopChart();
    this.chartTimerId = setInterval(() => {
      this.chartRaw = this.toPoints(this.rawHistory);
      this.chartFiltered = this.toPoints(this.filteredHistory);
    }, Constants.CHART_REFRESH_MS);
  }

  private stopChart(): void {
    if (this.chartTimerId !== -1) {
      clearInterval(this.chartTimerId);
      this.chartTimerId = -1;
    }
  }

  private toPoints(values: number[]): number[][] {
    const step = CHART_WIDTH / (Constants.CHART_POINTS - 1);
    const half = CHART_HEIGHT / 2;
    return values.map((value: number, i: number) => {
      const clamped = Math.min(Math.max(value, -Constants.CHART_RANGE), Constants.CHART_RANGE);
      return [i * step, half - clamped * half / Constants.CHART_RANGE];
    });
  }

  private deadzoneY(sign: number): number {
    const half = CHART_HEIGHT / 2;
    return half - sign * Math.min(this.settings.deadzone, Constants.CHART_RANGE) * half / Constants.CHART_RANGE;
  }

  private addLog(message: string, level: LogLevel = LogLevel.INFO): void {
    const entry = Logger.log(message, level);
    this.logs = [entry, ...this.logs].slice(0, Constants.LOG_LIMIT);
  }

  // ---------- View helpers ----------

  private sourceColor(): ResourceColor {
    switch (this.source) {
      case InputSource.TOUCH:
        return $r('app.color.accent');
      case InputSource.CROWN:
        return '#BF5AF2';
      case InputSource.TILT:
        return $r('app.color.success');
      default:
        return $r('app.color.neutral');
    }
  }

  private logColor(level: LogLevel): ResourceColor {
    switch (level) {
      case LogLevel.ERROR:
        return $r('app.color.error');
      case LogLevel.WARN:
        return $r('app.color.warning');
      default:
        return '#AEAEB2';
    }
  }

  // ---------- Layout ----------

  @Builder
  arena() {
    Stack() {
      Circle()
        .width(6)
        .height(6)
        .fill('#3A3A3C')
      Circle()
        .width(Constants.OBJECT_RADIUS * 2 * this.objectState.zoom)
        .height(Constants.OBJECT_RADIUS * 2 * this.objectState.zoom)
        .fill(this.sourceColor())
        .offset({ x: this.objectState.x, y: this.objectState.y })
    }
    .width('62%')
    .aspectRatio(1)
    .borderRadius(1000)
    .border({ width: 2, color: '#3A3A3C' })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.arenaRadius = Number(newValue.width) / 2 - 2;
    })
    .gesture(PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
      .onActionStart(() => this.onPanStart())
      .onActionUpdate((event: GestureEvent) => this.onPanUpdate(event))
      .onActionEnd((event: GestureEvent) => this.onPanEnd(event))
      .onActionCancel(() => this.onPanEnd(undefined)))
  }

  /** Source label, arena and buttons in one column, so that nothing covers the arena. */
  @Builder
  mainView() {
    Column({ space: 4 }) {
      Text(this.source)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.Black)
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor(this.sourceColor())
      Text(`tilt: ${this.tiltSource} · zoom ${this.objectState.zoom.toFixed(2)}`)
        .fontSize(10)
        .fontColor(this.tiltSource === TiltSource.SIM ? $r('app.color.warning') : $r('app.color.neutral'))
      this.arena()
      Row({ space: 8 }) {
        Button($r('app.string.btn_center'))
          .width(62)
          .height(28)
          .padding({ left: 4, right: 4 })
          .fontSize(11)
          .backgroundColor($r('app.color.card'))
          .onClick(() => this.centerObject())
        Button($r('app.string.settings'))
          .width(62)
          .height(28)
          .padding({ left: 4, right: 4 })
          .fontSize(11)
          .backgroundColor($r('app.color.card'))
          .onClick(() => this.openPanel())
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  chart() {
    Text($r('app.string.chart'))
      .fontSize(11)
      .fontColor($r('app.color.neutral'))
    Stack() {
      Line()
        .startPoint([0, this.deadzoneY(1)])
        .endPoint([CHART_WIDTH, this.deadzoneY(1)])
        .stroke('#48484A')
        .strokeDashArray([3, 3])
      Line()
        .startPoint([0, this.deadzoneY(-1)])
        .endPoint([CHART_WIDTH, this.deadzoneY(-1)])
        .stroke('#48484A')
        .strokeDashArray([3, 3])
      Polyline()
        .points(this.chartRaw)
        .stroke('#8E8E93')
        .strokeWidth(1)
        .fillOpacity(0)
      Polyline()
        .points(this.chartFiltered)
        .stroke($r('app.color.success'))
        .strokeWidth(2)
        .fillOpacity(0)
    }
    .width(CHART_WIDTH)
    .height(CHART_HEIGHT)
    .backgroundColor('#111113')
    .borderRadius(6)
    .alignContent(Alignment.TopStart)
  }

  @Builder
  panel() {
    Scroll() {
      Column({ space: 6 }) {
        Text($r('app.string.settings'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)

        StepperRow({
          label: $r('app.string.deadzone'),
          value: this.settings.deadzone.toFixed(1),
          onMinus: () => this.changeSettings((s: InputSettings) => {
            s.deadzone -= Constants.DEADZONE_STEP;
          }),
          onPlus: () => this.changeSettings((s: InputSettings) => {
            s.deadzone += Constants.DEADZONE_STEP;
          })
        })
        StepperRow({
          label: $r('app.string.alpha'),
          value: this.settings.alpha.toFixed(2),
          onMinus: () => this.changeSettings((s: InputSettings) => {
            s.alpha -= Constants.ALPHA_STEP;
          }),
          onPlus: () => this.changeSettings((s: InputSettings) => {
            s.alpha += Constants.ALPHA_STEP;
          })
        })
        StepperRow({
          label: $r('app.string.sensitivity'),
          value: this.settings.sensitivity.toFixed(1),
          onMinus: () => this.changeSettings((s: InputSettings) => {
            s.sensitivity -= Constants.SENSITIVITY_STEP;
          }),
          onPlus: () => this.changeSettings((s: InputSettings) => {
            s.sensitivity += Constants.SENSITIVITY_STEP;
          })
        })
        ToggleRow({
          label: $r('app.string.inertia'),
          isOn: this.settings.inertia,
          onToggle: (isOn: boolean) => this.changeSettings((s: InputSettings) => {
            s.inertia = isOn;
          })
        })

        this.chart()

        ToggleRow({
          label: $r('app.string.simulated_tilt'),
          isOn: this.simulate,
          onToggle: (isOn: boolean) => this.onSimChange(isOn)
        })
        if (this.tiltSource === TiltSource.SIM) {
          ToggleRow({
            label: $r('app.string.sim_jitter'),
            isOn: this.simJitter,
            onToggle: (isOn: boolean) => {
              this.simJitter = isOn;
              this.lifecycle.simJitter = isOn;
            }
          })
          Text($r('app.string.sim_tilt_x'))
            .fontSize(11)
            .fontColor($r('app.color.neutral'))
          Slider({ value: this.simX, min: -3, max: 3, step: 0.1 })
            .width('76%')
            .onChange((value: number) => {
              this.simX = value;
              this.lifecycle.simTilt = new Vec2(value, this.simY);
            })
          Text($r('app.string.sim_tilt_y'))
            .fontSize(11)
            .fontColor($r('app.color.neutral'))
          Slider({ value: this.simY, min: -3, max: 3, step: 0.1 })
            .width('76%')
            .onChange((value: number) => {
              this.simY = value;
              this.lifecycle.simTilt = new Vec2(this.simX, value);
            })
        }

        Row() {
          Text($r('app.string.subscriptions'))
            .fontSize(12)
            .fontColor('#C7C7CC')
            .layoutWeight(1)
          Text(`${this.subscriptions} · frame ${this.frameCallbackOn ? 'on' : 'off'}`)
            .fontSize(13)
            .fontColor(Color.White)
        }
        .width('80%')

        Text($r('app.string.event_log'))
          .fontSize(13)
          .fontColor($r('app.color.neutral'))
          .margin({ top: 6 })
        ForEach(this.logs, (entry: LogEntry) => {
          Text(`${entry.time}  ${entry.message}`)
            .width('76%')
            .fontSize(11)
            .fontColor(this.logColor(entry.level))
        }, (entry: LogEntry) => entry.id.toString())

        Button($r('app.string.close'))
          .width(120)
          .height(40)
          .margin({ top: 8 })
          .backgroundColor($r('app.color.accent'))
          .onClick(() => this.closePanel())
      }
      .width('100%')
      .padding({ top: 40, bottom: 56 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#F2000000')
  }

  build() {
    Stack() {
      this.mainView()
      if (this.showPanel) {
        this.panel()
      }
    }
    .id(ROOT_ID)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    // A container gets focus only through a focusable child (here: the HUD buttons).
    .focusable(true)
    .defaultFocus(true)
    .onDigitalCrown((event: CrownEvent) => this.onCrown(event))
  }
}
