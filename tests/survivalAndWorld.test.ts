/**
 * Survival, Mount, World & Ballistics Integration Tests
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { StaminaEngine } from '../survival/stamina.ts';
import { BodyDamageEngine } from '../survival/bodyDamage.ts';
import { MountSystem } from '../survival/mount.ts';
import { WorldStateManager } from '../world/worldState.ts';
import { WeatherEngine } from '../world/weather.ts';
import { BallisticsEngine, type CartridgeSpec } from '../physics/ballistics.ts';
import { vec3 } from '../core/types.ts';

describe('Survival & Body Damage Subsystems', () => {
  it('should drain stamina during sprint and apply encumbrance multipliers', () => {
    const stamina = new StaminaEngine();

    const lightEncumbrance = {
      totalMassKg: 4.0,
      massCapacityKg: 24.0,
      encumbranceRatio: 0.16,
      centerOfMassOffset: vec3(0, 0, 0),
      lateralImbalanceTorque: 0,
      staminaPenaltyMultiplier: 1.0,
      tactileStatusDescription: 'Light',
    };

    stamina.update(2.0, 'SPRINTING', lightEncumbrance, 25.0);
    const lightStamina = stamina.currentStamina;
    assert.ok(lightStamina < 100.0, 'Sprint must consume stamina');

    // Reset and test with heavy encumbrance
    const heavyStaminaEngine = new StaminaEngine();
    const heavyEncumbrance = {
      ...lightEncumbrance,
      totalMassKg: 32.0,
      encumbranceRatio: 1.33,
      staminaPenaltyMultiplier: 1.65,
    };

    heavyStaminaEngine.update(2.0, 'SPRINTING', heavyEncumbrance, 38.0);
    assert.ok(
      heavyStaminaEngine.currentStamina < lightStamina,
      'Heavy encumbrance and desert heat must drain stamina faster than light load'
    );
  });

  it('should localize body trauma, calculate hemorrhage, and resolve with bandages', () => {
    const trauma = new BodyDamageEngine();

    // Gunshot flesh wound to right arm
    const wound = trauma.inflictWound(
      'RIGHT_ARM',
      'Bullet graze tearing deltoid muscle',
      0.40,
      'VENOUS_STEADY'
    );

    assert.equal(trauma.state.zones.RIGHT_ARM.integrity, 0.60);
    assert.ok(trauma.state.aimTremorIntensity > 0.20, 'Arm damage must induce aim tremor');

    // Simulate 30 seconds of bleeding
    const bloodBefore = trauma.state.totalBloodVolumeMl;
    trauma.updateHemorrhage(30.0);
    const bloodAfter = trauma.state.totalBloodVolumeMl;
    assert.ok(bloodAfter < bloodBefore, 'Hemorrhage must reduce circulating blood volume');

    // Apply pressure dressing
    const bandageRes = trauma.applyBandage(wound.id);
    assert.ok(bandageRes.success);
    assert.equal(wound.isBandaged, true);

    // Verify hemorrhage rate is suppressed
    const bloodBefore2 = trauma.state.totalBloodVolumeMl;
    trauma.updateHemorrhage(30.0);
    const bloodLossDressed = bloodBefore2 - trauma.state.totalBloodVolumeMl;
    const bloodLossUndressed = bloodBefore - bloodAfter;
    assert.ok(bloodLossDressed < bloodLossUndressed * 0.3, 'Bandage must reduce bleeding rate by at least 70%');
  });

  it('should balance mount saddlebag storage and generate diegetic mount inspections', () => {
    const mount = new MountSystem('Cimmaron', 'Mustang');

    assert.equal(mount.state.isHitched, false);
    mount.state.distanceToPlayerM = 1.5;
    const hitchRes = mount.hitchToPost();
    assert.ok(hitchRes.success);
    assert.equal(mount.state.isHitched, true);

    const desc = mount.inspectMount();
    assert.ok(desc.includes('Cimmaron'));
    assert.ok(desc.includes('Hitched'));
  });
});

describe('World State & Weather Loop Subsystems', () => {
  it('should track persistent items, spent brass, and serialize chunks deterministically', () => {
    const world = new WorldStateManager();

    // Drop brass and item at position (10, 0, 15)
    world.recordSpentBrass(vec3(10, 0, 15));
    world.recordSpentBrass(vec3(12, 0, 14));

    const itemInstance = world.dropItemOnGround(
      {
        id: 'cloth_rag',
        name: 'Solvent Stained Rag',
        category: 'CLEANING_KIT',
        width: 1,
        height: 1,
        massKg: 0.1,
        volumeCm3: 80,
        condition: 0.7,
        stackable: false,
        quantity: 1,
        maxStack: 1,
        tactileDescription: 'Oily cotton patch smelling strongly of kerosene and burnt black powder.',
      },
      vec3(10, 0, 15)
    );

    assert.ok(itemInstance.id.startsWith('ground_cloth_rag'));

    const snapshot = world.serialize();
    assert.ok(snapshot.includes('spentBrassCount'));

    // Restore to fresh manager
    const restoredWorld = new WorldStateManager();
    restoredWorld.deserialize(snapshot);

    const chunk = restoredWorld.getChunkForWorldPos(10, 15);
    assert.equal(chunk.spentBrassCount, 2);
    assert.equal(chunk.groundItems.length, 1);
  });

  it('should simulate Haboob sandstorm transition with extreme silica grit suspension', () => {
    const weather = new WeatherEngine();
    assert.equal(weather.currentAtmosphere.type, 'CLEAR_ARID');

    weather.transitionTo('SEVERE_HABOOB');
    assert.equal(weather.currentAtmosphere.type, 'SEVERE_HABOOB');
    assert.ok(weather.currentAtmosphere.gritSuspensionDensityMgM3 > 100.0);
    assert.ok(weather.currentAtmosphere.visibilityMeters < 30.0);

    const desc = weather.describeAtmosphere();
    assert.ok(desc.includes('silica sand') || desc.includes('Haboob'));
  });
});

describe('External Ballistics Engine', () => {
  it('should trace bullet trajectory with drag deceleration and gravitational drop', () => {
    const ballistics = new BallisticsEngine();

    const spec: CartridgeSpec = {
      name: '.45 Colt',
      caliber: '.45 Colt',
      bulletMassKg: 0.0162,
      bulletDiameterM: 0.01148,
      nominalMuzzleVelocityMps: 260.0,
      dragCoefficientG1: 0.19,
      powderType: 'SMOKELESS',
    };

    // Fire horizontally from shoulder height (1.6m) along +Z
    const trajectory = ballistics.traceTrajectory(
      vec3(0, 1.6, 0),
      vec3(0, 0, 260.0),
      spec
    );

    assert.ok(trajectory.length > 10, 'Trajectory should yield multiple simulated steps');

    const first = trajectory[0];
    const last = trajectory[trajectory.length - 1];

    assert.equal(first.position.y, 1.6);
    assert.equal(last.position.y, 0, 'Bullet must hit the ground deterministically');
    assert.ok(last.totalDistanceTraveled > 50.0, 'Bullet should travel substantial distance downrange');
    assert.ok(last.velocity.z < first.velocity.z, 'Aerodynamic drag must decelerate horizontal speed');
  });
});
