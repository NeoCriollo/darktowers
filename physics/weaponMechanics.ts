/**
 * Weapon Mechanics, Internal Ballistics & Degradation Engine
 * Pure modular component-based state machine for firearm mechanics and field maintenance.
 */

import type { CartridgeSpec } from './ballistics.ts';
import { type Result, ok, err } from '../core/types.ts';
import { globalEventBus } from '../core/eventBus.ts';
import { ENGINE_CONFIG } from '../core/config.ts';

export type ActionType =
  | 'REVOLVER_SINGLE_ACTION'
  | 'LEVER_ACTION'
  | 'BOLT_ACTION'
  | 'BREAK_ACTION';

export type ChamberState =
  | 'EMPTY'
  | 'CHAMBERED_LIVE'
  | 'CHAMBERED_SPENT'
  | 'JAMMED_STOVEPIPE'
  | 'JAMMED_FAILURE_TO_FEED'
  | 'JAMMED_FAILURE_TO_EXTRACT'
  | 'OUT_OF_BATTERY';

export type HammerState = 'DECOCKED' | 'HALF_COCK' | 'COCKED';

export type ManualClearMethod =
  | 'TAP_RACK'
  | 'STRIP_CASING'
  | 'ROD_EXTRACTION';

export interface WeaponStateConfig {
  id: string;
  modelName: string;
  actionType: ActionType;
  chamberCapacity: number;     // e.g. 6 for revolver, 8 for lever-action tube
  caliber: string;
  baseNominalVelocityMps: number;
}

export interface DiegeticInspectionReport {
  overallImpression: string;
  boreCondition: string;
  actionFeel: string;
  surfaceFinish: string;
  mechanicalStatus: string;
  tactileGritSeverity: 'PRISTINE' | 'FAINT' | 'GRATING' | 'SEIZED';
}

export class WeaponMechanics {
  public readonly config: WeaponStateConfig;

  // Mechanical states
  public chamber: ChamberState = 'EMPTY';
  public hammer: HammerState = 'DECOCKED';
  public internalMagazine: CartridgeSpec[] = []; // Rounds loaded in cylinder/tube

  // Physical wear & contamination metrics [0.0 - 1.0]
  public gritAccumulation: number = 0.0;     // Silica/sand particulate
  public barrelFouling: number = 0.0;        // Carbon/lead powder residue
  public corrosionIndex: number = 0.0;       // Rust/pitting
  public lubricationQuality: number = 0.85;  // Mineral oil film level
  public isHolstered: boolean = true;

  constructor(config: WeaponStateConfig) {
    this.config = config;
  }

  /**
   * Calculates the composite degradation index D in [0.0, 1.0].
   */
  public getCompositeDegradation(): number {
    const raw =
      0.45 * this.gritAccumulation +
      0.35 * this.barrelFouling +
      0.20 * this.corrosionIndex -
      0.25 * this.lubricationQuality;
    return Math.max(0.0, Math.min(1.0, raw));
  }

  /**
   * Internal ballistics: Barrel friction calculates velocity degradation.
   * V_actual = V_nominal * sqrt(max(0.15, 1.0 - 0.22*fouling - 0.38*grit - 0.30*corrosion))
   */
  public computeActualMuzzleVelocity(spec: CartridgeSpec): number {
    const frictionPenalty =
      0.22 * this.barrelFouling +
      0.38 * this.gritAccumulation +
      0.30 * this.corrosionIndex;

    const frictionRatio = Math.sqrt(Math.max(0.15, 1.0 - frictionPenalty));
    return spec.nominalMuzzleVelocityMps * frictionRatio;
  }

  /**
   * Computes probability of jam or mechanical cycling failure.
   * Uses logistic function centered at JAM_DEGRADATION_THRESHOLD.
   */
  public computeJamProbability(): number {
    const d = this.getCompositeDegradation();
    if (d <= 0.0) {
      return 0.0;
    }
    const threshold = ENGINE_CONFIG.JAM_DEGRADATION_THRESHOLD;
    const k = ENGINE_CONFIG.JAM_LOGISTIC_STEEPNESS;
    return 1.0 / (1.0 + Math.exp(-k * (d - threshold)));
  }

  /**
   * Accumulates environmental grit over elapsed time based on weather intensity.
   */
  public exposeToEnvironment(gritDensityMgM3: number, dtSeconds: number): void {
    const protection = this.isHolstered ? ENGINE_CONFIG.HOLSTER_PROTECTION_FACTOR : 0.0;
    const netExposure = (1.0 - protection) * (gritDensityMgM3 / 100.0);
    const addedGrit = netExposure * dtSeconds * 0.005;

    this.gritAccumulation = Math.min(1.0, this.gritAccumulation + addedGrit);

    // High grit rapidly degrades active oil lubrication
    if (addedGrit > 0) {
      this.lubricationQuality = Math.max(0.0, this.lubricationQuality - addedGrit * 0.4);
    }
  }

  /**
   * Applies salt-corrosion accumulation from saline/alkali playa environments (e.g. Dead-Creek Salt Flats).
   */
  public exposeToSaltCorrosion(dtSeconds: number, corrosionRateMultiplier: number = 1.0): void {
    const protection = this.isHolstered ? ENGINE_CONFIG.HOLSTER_PROTECTION_FACTOR : 0.0;
    const addedCorrosion = (1.0 - protection) * dtSeconds * 0.005 * corrosionRateMultiplier;
    this.corrosionIndex = Math.min(1.0, this.corrosionIndex + addedCorrosion);
    if (addedCorrosion > 0) {
      this.lubricationQuality = Math.max(0.0, this.lubricationQuality - addedCorrosion * 0.8);
    }
  }

  /**
   * Manual Action: Cock the hammer.
   */
  public cockHammer(): Result<void, string> {
    if (this.chamber.startsWith('JAMMED_')) {
      return err('Hammer cannot be fully cocked; internal linkage is bound by mechanical jam.');
    }

    // Heavy grit can cause hammer to stick or fail to catch sear
    if (this.gritAccumulation > 0.75 && Math.random() < 0.35) {
      this.hammer = 'HALF_COCK';
      return err('Hammer slips on gritty sear notch and drops to half-cock safety.');
    }

    this.hammer = 'COCKED';
    return ok(undefined);
  }

  /**
   * Manual Action: Pull the trigger to strike primer.
   */
  public pullTrigger(activeSpec?: CartridgeSpec): Result<{ fired: boolean; velocityMps?: number; casingState: ChamberState }, string> {
    if (this.hammer !== 'COCKED') {
      return err('Trigger clicks loosely; hammer is not cocked.');
    }

    this.hammer = 'DECOCKED';

    if (this.chamber === 'EMPTY') {
      return ok({ fired: false, casingState: 'EMPTY' }); // Dry fire
    }

    if (this.chamber === 'CHAMBERED_SPENT') {
      return ok({ fired: false, casingState: 'CHAMBERED_SPENT' }); // Click on dead brass
    }

    if (this.chamber !== 'CHAMBERED_LIVE') {
      return err(`Cannot strike primer while firearm is in state: ${this.chamber}`);
    }

    // Live round in chamber: Check for light strike due to heavy grit in firing pin channel
    if (this.gritAccumulation > 0.70 && Math.random() < (this.gritAccumulation - 0.65) * 2.0) {
      // Light strike: round does not detonate
      return ok({ fired: false, casingState: 'CHAMBERED_LIVE' });
    }

    // Round fires successfully!
    const spec = activeSpec ?? {
      name: '.45 Cold Wasteland Lead',
      caliber: this.config.caliber,
      bulletMassKg: 0.0162,
      bulletDiameterM: 0.01148,
      nominalMuzzleVelocityMps: this.config.baseNominalVelocityMps,
      dragCoefficientG1: 0.19,
      powderType: 'SMOKELESS',
    };

    const actualVelocity = this.computeActualMuzzleVelocity(spec);

    // Apply firing fouling
    const foulingIncrement = spec.powderType === 'BLACK_POWDER'
      ? ENGINE_CONFIG.CARBON_FOULING_PER_SHOT_BLACK_POWDER
      : ENGINE_CONFIG.CARBON_FOULING_PER_SHOT_STANDARD;
    this.barrelFouling = Math.min(1.0, this.barrelFouling + foulingIncrement);

    // High chamber temperature burns off minute fraction of lubrication
    this.lubricationQuality = Math.max(0.0, this.lubricationQuality - 0.008);

    this.chamber = 'CHAMBERED_SPENT';

    globalEventBus.emit('weapon:fired', {
      weaponId: this.config.id,
      muzzleVelocity: actualVelocity,
      caliber: this.config.caliber,
      barrelFouling: this.barrelFouling,
      position: { x: 0, y: 1.5, z: 0 },
      direction: { x: 0, y: 0, z: 1 },
    });

    return ok({ fired: true, velocityMps: actualVelocity, casingState: 'CHAMBERED_SPENT' });
  }

  /**
   * Manual Action: Cycle the action (throw lever, pull bolt, or advance cylinder).
   * Ejects current chambered round (live or spent) and feeds next cartridge from magazine.
   */
  public cycleAction(): Result<{ ejected: ChamberState; newlyChambered: ChamberState }, string> {
    if (this.chamber.startsWith('JAMMED_')) {
      return err(`Action is bound tight by ${this.chamber}. Clear jam before cycling.`);
    }

    const previousChamber = this.chamber;
    const jamProb = this.computeJamProbability();
    const roll = Math.random();

    // Check for cycling failure / jam roll
    if (roll < jamProb) {
      if (previousChamber === 'CHAMBERED_SPENT') {
        // Did extractor slip over tight dirty rim? Or did casing stovepipe?
        if (this.barrelFouling > 0.55 || this.corrosionIndex > 0.40) {
          this.chamber = 'JAMMED_FAILURE_TO_EXTRACT';
        } else {
          this.chamber = 'JAMMED_STOVEPIPE';
        }
      } else {
        this.chamber = 'JAMMED_FAILURE_TO_FEED';
      }

      globalEventBus.emit('weapon:jammed', {
        weaponId: this.config.id,
        malfunctionType: this.chamber,
        degradationIndex: this.getCompositeDegradation(),
      });

      return err(`Action jammed during stroke: ${this.chamber}`);
    }

    // Successful ejection and chambering
    const nextRound = this.internalMagazine.shift();
    if (nextRound) {
      this.chamber = 'CHAMBERED_LIVE';
    } else {
      this.chamber = 'EMPTY';
    }

    // For single-action revolvers or lever actions, cycling might cock the hammer
    if (this.config.actionType === 'LEVER_ACTION') {
      this.hammer = 'COCKED';
    }

    return ok({ ejected: previousChamber, newlyChambered: this.chamber });
  }

  /**
   * Manual Action: Load an individual cartridge into the magazine/cylinder.
   */
  public insertRound(round: CartridgeSpec): Result<number, string> {
    if (this.internalMagazine.length >= this.config.chamberCapacity) {
      return err(`Magazine/cylinder is already full (${this.config.chamberCapacity} rounds).`);
    }

    if (round.caliber !== this.config.caliber) {
      return err(`Caliber mismatch: Cannot load ${round.caliber} into ${this.config.caliber} chamber.`);
    }

    this.internalMagazine.push(round);
    return ok(this.internalMagazine.length);
  }

  /**
   * Manual Action: Tactile jam clearing attempt.
   */
  public clearJam(method: ManualClearMethod): Result<string, string> {
    if (!this.chamber.startsWith('JAMMED_')) {
      return err('Action is not currently jammed.');
    }

    const currentJam = this.chamber;

    switch (currentJam) {
      case 'JAMMED_STOVEPIPE': {
        if (method === 'TAP_RACK' || method === 'STRIP_CASING') {
          this.chamber = 'EMPTY';
          return ok('Pinched brass casing extracted with thumb and clear stroke; chamber is cleared.');
        }
        return err('Rod extraction is unnecessary for a stovepipe casing; thumb swipe or tap-rack required.');
      }

      case 'JAMMED_FAILURE_TO_FEED': {
        if (method === 'STRIP_CASING' || method === 'TAP_RACK') {
          this.chamber = 'EMPTY';
          return ok('Misaligned cartridge stripped from feed lips; bolt face cleared.');
        }
        return err('Feed ramp obstruction must be stripped from receiver.');
      }

      case 'JAMMED_FAILURE_TO_EXTRACT': {
        if (method === 'TAP_RACK') {
          return err('Extractor slips off seized brass rim with a sickening scrape. Casing remains lodged tight in chamber.');
        }
        if (method === 'ROD_EXTRACTION') {
          this.chamber = 'EMPTY';
          return ok('Brass cleaning rod driven down the muzzle knocks out the swollen ruptured casing with a sharp pop.');
        }
        return err('Stuck case cannot be cleared by hand strip. Requires cleaning rod pushed down the muzzle.');
      }

      default:
        this.chamber = 'EMPTY';
        return ok('Mechanical obstruction forced free.');
    }
  }

  // ==================== TACTILE MAINTENANCE LOOP ====================

  /**
   * Maintenance Step 1: Solvent & Bore Patch.
   * Swabs out carbon soot, black powder residue, and unburnt propellant.
   */
  public cleanBore(patchQuality: number, solventQuality: number): { foulingRemoved: number; gritRemoved: number } {
    const cleaningPower = (patchQuality * 0.45 + solventQuality * 0.55);
    const foulingRemoved = Math.min(this.barrelFouling, this.barrelFouling * cleaningPower * 0.85 + 0.15);
    const gritRemoved = Math.min(this.gritAccumulation, this.gritAccumulation * cleaningPower * 0.35);

    this.barrelFouling = Math.max(0.0, this.barrelFouling - foulingRemoved);
    this.gritAccumulation = Math.max(0.0, this.gritAccumulation - gritRemoved);

    // Solvent strips remaining degraded oil film
    this.lubricationQuality = Math.max(0.05, this.lubricationQuality - 0.3);

    globalEventBus.emit('weapon:cleaned', {
      weaponId: this.config.id,
      gritRemoved,
      foulingRemoved,
      newCondition: 1.0 - this.getCompositeDegradation(),
    });

    return { foulingRemoved, gritRemoved };
  }

  /**
   * Maintenance Step 2: Brass Brush & Scraper.
   * Mechanically dislodges coarse sand and grit from receiver tracks, bolt lugs, and extractor star.
   */
  public brushActionAndRails(brushQuality: number): { gritRemoved: number } {
    const gritRemoved = Math.min(this.gritAccumulation, this.gritAccumulation * brushQuality * 0.75 + 0.10);
    this.gritAccumulation = Math.max(0.0, this.gritAccumulation - gritRemoved);

    return { gritRemoved };
  }

  /**
   * Maintenance Step 3: Lubrication & Rust Inhibitor.
   * Applies mineral/synthetic gun oil, restoring smooth mechanical action and halting corrosion.
   */
  public lubricate(oilQuality: number): { newLubrication: number } {
    this.lubricationQuality = Math.min(1.0, this.lubricationQuality + oilQuality * 0.8);
    // Light oil loosens surface corrosion
    this.corrosionIndex = Math.max(0.0, this.corrosionIndex - oilQuality * 0.15);

    return { newLubrication: this.lubricationQuality };
  }

  // ==================== DIEGETIC INSPECTION ====================

  /**
   * Generates sensory, diegetic description of the weapon without floating numbers.
   */
  public inspect(): DiegeticInspectionReport {
    // 1. Bore condition
    let boreCondition: string;
    if (this.barrelFouling < 0.10 && this.gritAccumulation < 0.08) {
      boreCondition = 'Rifling spiral gleams bright and clean down the bore with a mirror reflection.';
    } else if (this.barrelFouling < 0.35) {
      boreCondition = 'A light dark powder haze coats the rifling grooves, but lands remain sharp.';
    } else if (this.barrelFouling < 0.70) {
      boreCondition = 'Heavy black carbon fouling crusts the bore; rifling grooves are noticeably choked with soot.';
    } else {
      boreCondition = 'Bore is crusted in thick burnt slag and gritty deposits. Extractor throat is choked with grime.';
    }

    // 2. Action feel
    let actionFeel: string;
    let tactileGritSeverity: DiegeticInspectionReport['tactileGritSeverity'];
    if (this.gritAccumulation < 0.10 && this.lubricationQuality > 0.60) {
      actionFeel = 'Action strokes silky smooth with a crisp, oiled mechanical snap on lockup.';
      tactileGritSeverity = 'PRISTINE';
    } else if (this.gritAccumulation < 0.30) {
      actionFeel = 'A faint gritty vibration hums through the steel when working the lever.';
      tactileGritSeverity = 'FAINT';
    } else if (this.gritAccumulation < 0.65) {
      actionFeel = 'Coarse grinding drag on the bolt face; lever requires muscle to force through the stroke.';
      tactileGritSeverity = 'GRATING';
    } else {
      actionFeel = 'Bolt linkage is seizing tight with dry silica grit; steel scrapes agonizingly against steel.';
      tactileGritSeverity = 'SEIZED';
    }

    // 3. Surface & Finish
    let surfaceFinish: string;
    if (this.corrosionIndex < 0.10) {
      surfaceFinish = this.lubricationQuality > 0.4
        ? 'Deep blued finish is protected by a wet film of gun oil.'
        : 'Blued steel is dry and matte to the touch.';
    } else if (this.corrosionIndex < 0.40) {
      surfaceFinish = 'Patches of fine orange freckling have begun to pit the barrel and cylinder frame.';
    } else {
      surfaceFinish = 'Heavy reddish rust scale bites into the screws and roughs up the receiver walls.';
    }

    // 4. Mechanical status
    let mechanicalStatus: string;
    if (this.chamber === 'EMPTY') {
      mechanicalStatus = `Chamber is empty. Magazine holds ${this.internalMagazine.length}/${this.config.chamberCapacity} rounds.`;
    } else if (this.chamber === 'CHAMBERED_LIVE') {
      mechanicalStatus = `Live brass seated in battery. Hammer is ${this.hammer.toLowerCase()}.`;
    } else if (this.chamber === 'CHAMBERED_SPENT') {
      mechanicalStatus = 'Fired, blackened casing remains lodged in chamber awaiting extraction.';
    } else {
      mechanicalStatus = `MALFUNCTION: ${this.chamber}. Action is pinned open.`;
    }

    const overallImpression = `[${this.config.modelName}] ${boreCondition} ${actionFeel} ${surfaceFinish}`;

    return {
      overallImpression,
      boreCondition,
      actionFeel,
      surfaceFinish,
      mechanicalStatus,
      tactileGritSeverity,
    };
  }
}
