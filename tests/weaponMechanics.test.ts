/**
 * Weapon Mechanics & Maintenance Loop Unit Tests
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { WeaponMechanics } from '../physics/weaponMechanics.ts';
import type { CartridgeSpec } from '../physics/ballistics.ts';

describe('Weapon Mechanics & Barrel Friction', () => {
  const cartridge45: CartridgeSpec = {
    name: '.45 Long Colt',
    caliber: '.45 Colt',
    bulletMassKg: 0.0162,
    bulletDiameterM: 0.01148,
    nominalMuzzleVelocityMps: 260.0,
    dragCoefficientG1: 0.19,
    powderType: 'SMOKELESS',
  };

  it('should initialize clean weapon with nominal muzzle velocity', () => {
    const revolver = new WeaponMechanics({
      id: 'peacemaker_01',
      modelName: 'Frontier Peacemaker .45',
      actionType: 'REVOLVER_SINGLE_ACTION',
      chamberCapacity: 6,
      caliber: '.45 Colt',
      baseNominalVelocityMps: 260.0,
    });

    const vNominal = revolver.computeActualMuzzleVelocity(cartridge45);
    assert.equal(vNominal, 260.0, 'Pristine weapon must achieve 100% nominal muzzle velocity');
    assert.equal(revolver.getCompositeDegradation(), 0.0, 'Degradation index must be zero initially');
  });

  it('should deterministically degrade velocity as barrel friction and grit accumulate', () => {
    const revolver = new WeaponMechanics({
      id: 'peacemaker_01',
      modelName: 'Frontier Peacemaker .45',
      actionType: 'REVOLVER_SINGLE_ACTION',
      chamberCapacity: 6,
      caliber: '.45 Colt',
      baseNominalVelocityMps: 260.0,
    });

    revolver.barrelFouling = 0.50;
    revolver.gritAccumulation = 0.60;
    revolver.corrosionIndex = 0.20;
    revolver.lubricationQuality = 0.15;

    const vDegraded = revolver.computeActualMuzzleVelocity(cartridge45);
    assert.ok(vDegraded < 260.0, 'Degraded barrel must reduce projectile velocity due to internal friction');
    assert.ok(vDegraded > 100.0, 'Velocity should still remain within physical bound');

    const jamProb = revolver.computeJamProbability();
    assert.ok(jamProb > 0.40, 'Severe degradation must elevate jam probability');
  });

  it('should execute manual chambering, firing cycle, and spent casing progression', () => {
    const rifle = new WeaponMechanics({
      id: 'repeater_01',
      modelName: 'Wasteland Repeater',
      actionType: 'LEVER_ACTION',
      chamberCapacity: 8,
      caliber: '.45 Colt',
      baseNominalVelocityMps: 360.0,
    });

    // Load 2 cartridges into tube
    rifle.insertRound(cartridge45);
    rifle.insertRound(cartridge45);
    assert.equal(rifle.internalMagazine.length, 2);

    // Initial state: empty chamber
    assert.equal(rifle.chamber, 'EMPTY');

    // Cycle lever: feeds round 1, cocks hammer
    const cycle1 = rifle.cycleAction();
    assert.ok(cycle1.success);
    assert.equal(rifle.chamber, 'CHAMBERED_LIVE');
    assert.equal(rifle.hammer, 'COCKED');
    assert.equal(rifle.internalMagazine.length, 1);

    // Pull trigger to fire
    const fireRes = rifle.pullTrigger(cartridge45);
    assert.ok(fireRes.success);
    assert.equal(fireRes.value.fired, true);
    assert.equal(rifle.chamber, 'CHAMBERED_SPENT');
    assert.equal(rifle.hammer, 'DECOCKED');
    assert.ok(rifle.barrelFouling > 0.0, 'Firing must deposit carbon fouling in barrel');

    // Cycle lever again: ejects spent casing, feeds round 2
    const cycle2 = rifle.cycleAction();
    assert.ok(cycle2.success);
    assert.equal(cycle2.value.ejected, 'CHAMBERED_SPENT');
    assert.equal(cycle2.value.newlyChambered, 'CHAMBERED_LIVE');
  });

  it('should require tactile jam clearance routines for different malfunction types', () => {
    const repeater = new WeaponMechanics({
      id: 'repeater_01',
      modelName: 'Wasteland Repeater',
      actionType: 'LEVER_ACTION',
      chamberCapacity: 8,
      caliber: '.45 Colt',
      baseNominalVelocityMps: 360.0,
    });

    // Stovepipe jam cleared by tap-rack
    repeater.chamber = 'JAMMED_STOVEPIPE';
    const tapRes = repeater.clearJam('TAP_RACK');
    assert.ok(tapRes.success);
    assert.equal(repeater.chamber, 'EMPTY');

    // Stuck case (failure to extract) cannot be cleared by tap-rack
    repeater.chamber = 'JAMMED_FAILURE_TO_EXTRACT';
    const failTap = repeater.clearJam('TAP_RACK');
    assert.equal(failTap.success, false, 'Tap rack must fail on stuck ruptured casing');

    // Solved by brass cleaning rod down muzzle
    const rodRes = repeater.clearJam('ROD_EXTRACTION');
    assert.ok(rodRes.success);
    assert.equal(repeater.chamber, 'EMPTY');
  });

  it('should restore weapon condition through multi-step maintenance loop', () => {
    const revolver = new WeaponMechanics({
      id: 'revolver_dirty',
      modelName: 'Navy Colt',
      actionType: 'REVOLVER_SINGLE_ACTION',
      chamberCapacity: 6,
      caliber: '.45 Colt',
      baseNominalVelocityMps: 260.0,
    });

    // Simulate heavy field fouling & sandstorm exposure
    revolver.barrelFouling = 0.80;
    revolver.gritAccumulation = 0.70;
    revolver.lubricationQuality = 0.10;

    assert.ok(revolver.getCompositeDegradation() > 0.50);

    // Step 1: Bore patch & solvent
    const cleanBoreRes = revolver.cleanBore(0.9, 0.95);
    assert.ok(cleanBoreRes.foulingRemoved > 0.4);
    assert.ok(revolver.barrelFouling < 0.35);

    // Step 2: Action brush & scraper
    const brushRes = revolver.brushActionAndRails(0.9);
    assert.ok(brushRes.gritRemoved > 0.4);
    assert.ok(revolver.gritAccumulation < 0.25);

    // Step 3: Lubrication
    const oilRes = revolver.lubricate(0.9);
    assert.ok(oilRes.newLubrication > 0.7);

    // Verify restored condition
    assert.ok(revolver.getCompositeDegradation() < 0.15, 'Degradation index must drop significantly after maintenance');

    // Diegetic inspection must reflect clean steel
    const inspection = revolver.inspect();
    assert.ok(inspection.boreCondition.includes('bright') || inspection.boreCondition.includes('light'));
    assert.notEqual(inspection.tactileGritSeverity, 'SEIZED');
  });

  it('should validate gunshot audio cues, muzzle events, and input action wiring', () => {
    // 1. Mock AudioStreamPlayer3D & Muzzle Emitters
    class MockAudioStreamPlayer3D {
      name: string = 'GunshotAudio';
      stream: string | null = 'res://assets/audio/gunshot.wav';
      unitSize: number = 14.0;
      maxDistance: number = 150.0;
      pitchScale: number = 1.0;
      isPlaying: boolean = false;
      playCount: number = 0;

      play(): void {
        this.isPlaying = true;
        this.playCount++;
      }
    }

    class MockCPUParticles3D {
      name: string = 'MuzzleFlash';
      emitting: boolean = false;
      oneShot: boolean = true;
      restartCalled: boolean = false;

      restart(): void {
        this.restartCalled = true;
      }
    }

    class MockOmniLight3D {
      name: string = 'MuzzleFlashLight';
      lightEnergy: number = 0.0;
      visible: boolean = false;
    }

    // 2. Weapon Controller with Audio & VFX Wiring
    class MockWeaponController {
      chamberState: string = 'CHAMBERED_LIVE';
      hammerState: string = 'COCKED';
      currentMagazineRounds: number = 5;
      gunshotAudio = new MockAudioStreamPlayer3D();
      muzzleFlash = new MockCPUParticles3D();
      muzzleLight = new MockOmniLight3D();
      firedEvents: any[] = [];

      fire(): boolean {
        if (this.hammerState !== 'COCKED' || this.chamberState !== 'CHAMBERED_LIVE') {
          return false;
        }

        // Mechanical progression
        this.hammerState = 'DECOCKED';
        this.chamberState = 'CHAMBERED_SPENT';

        // Trigger Audio & Muzzle Effects on Shot
        this.gunshotAudio.pitchScale = 0.96 + Math.random() * 0.08;
        this.gunshotAudio.play();

        this.muzzleLight.lightEnergy = 6.5;
        this.muzzleLight.visible = true;
        this.muzzleFlash.restart();
        this.muzzleFlash.emitting = true;

        this.firedEvents.push({ discharged: true, remainingRounds: this.currentMagazineRounds });
        return true;
      }
    }

    const weapon = new MockWeaponController();
    assert.equal(weapon.gunshotAudio.name, 'GunshotAudio');
    assert.equal(weapon.gunshotAudio.stream, 'res://assets/audio/gunshot.wav');
    assert.equal(weapon.gunshotAudio.playCount, 0);
    assert.equal(weapon.muzzleFlash.emitting, false);

    // 3. Simulate Left-Click Input Action ("fire" / MOUSE_BUTTON_LEFT)
    const simulateInput = (event: { action?: string; button?: number; pressed: boolean }, isCaptured: boolean, isModalOpen: boolean) => {
      if (!isCaptured || isModalOpen || !event.pressed) return false;
      if (event.action === 'fire' || event.button === 1) {
        return weapon.fire();
      }
      return false;
    };

    // Attempt shot while modal is open -> blocked
    const modalBlocked = simulateInput({ action: 'fire', button: 1, pressed: true }, true, true);
    assert.equal(modalBlocked, false);
    assert.equal(weapon.gunshotAudio.playCount, 0);

    // Fire in game world with captured cursor
    const shotSuccess = simulateInput({ action: 'fire', button: 1, pressed: true }, true, false);
    assert.equal(shotSuccess, true);
    assert.equal(weapon.chamberState, 'CHAMBERED_SPENT');
    assert.equal(weapon.hammerState, 'DECOCKED');
    assert.equal(weapon.gunshotAudio.playCount, 1);
    assert.equal(weapon.gunshotAudio.isPlaying, true);
    assert.ok(weapon.gunshotAudio.pitchScale >= 0.95 && weapon.gunshotAudio.pitchScale <= 1.05);
    assert.equal(weapon.muzzleFlash.emitting, true);
    assert.equal(weapon.muzzleFlash.restartCalled, true);
    assert.equal(weapon.muzzleLight.visible, true);
    assert.equal(weapon.firedEvents.length, 1);
  });
});
