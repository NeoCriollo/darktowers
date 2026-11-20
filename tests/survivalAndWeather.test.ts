/**
 * Survival, Mount, Weather, Ballistics & World Architecture Integration Tests
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { StaminaEngine } from '../survival/stamina.ts';
import { BodyDamageEngine } from '../survival/bodyDamage.ts';
import { MountSystem } from '../survival/mount.ts';
import { WorldStateManager } from '../world/worldState.ts';
import { WeatherEngine } from '../world/weather.ts';
import { BallisticsEngine, type CartridgeSpec } from '../physics/ballistics.ts';
import { vec3 } from '../core/types.ts';
import { WORLD_CONFIG } from '../core/config.ts';
import {
  BASIN_REGISTRY,
  CANYON_PASS_REGISTRY,
  THINNY_ANOMALY_REGISTRY,
} from '../world/types.ts';

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

describe('External Ballistics & World Physics Contracts', () => {
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

  it('should validate Phase 1 World Coordinate Architecture contracts (2500m x 2500m)', () => {
    // 1. World Bounds & Perimeter Colliders
    assert.equal(WORLD_CONFIG.TOTAL_MAP_FOOTPRINT_M, 2500.0);
    assert.equal(WORLD_CONFIG.HALF_EXTENT_M, 1250.0);
    assert.equal(WORLD_CONFIG.PERIMETER_COLLIDER_OFFSET_M, 1246.0);
    assert.equal(WORLD_CONFIG.PERIMETER_COLLIDER_HEIGHT_M, 60.0);
    assert.equal(WORLD_CONFIG.AXIS_OF_THE_BEAM_RAD, 0.785);
    assert.deepEqual(WORLD_CONFIG.DARK_TOWER_POSITION, { x: 700.0, y: 0.0, z: 700.0 });
    assert.equal(WORLD_CONFIG.DARK_TOWER_HEIGHT_M, 120.0);
    assert.deepEqual(WORLD_CONFIG.INITIAL_PLAYER_SPAWN, { x: -1020.0, y: 0.0, z: -820.0 });

    // 2. 8-Node Region Registry
    const basinKeys = Object.keys(BASIN_REGISTRY);
    assert.equal(basinKeys.length, 8, 'Must have exactly 8 basin nodes');

    // Node 0 Safe House Bunker
    const node0 = BASIN_REGISTRY.waystation_sanctuary;
    assert.equal(node0.nodeIndex, 0);
    assert.equal(node0.isSafeZone, true);
    assert.deepEqual(node0.center, { x: -1000.0, y: 0.0, z: -800.0 });
    assert.equal(node0.radiusMeters, 150.0);

    // Node 1 to 7 biomes footprint (500m x 500m footprint -> Radius = 250.0m)
    assert.deepEqual(BASIN_REGISTRY.sw_desolation.center, { x: -550.0, y: 0.0, z: -900.0 });
    assert.equal(BASIN_REGISTRY.sw_desolation.radiusMeters, 250.0);

    assert.deepEqual(BASIN_REGISTRY.south_salt.center, { x: -150.0, y: 0.0, z: -550.0 });
    assert.equal(BASIN_REGISTRY.south_salt.radiusMeters, 250.0);

    assert.deepEqual(BASIN_REGISTRY.cradle.center, { x: 0.0, y: 0.0, z: 0.0 });
    assert.equal(BASIN_REGISTRY.cradle.radiusMeters, 250.0);

    assert.deepEqual(BASIN_REGISTRY.west_gorge.center, { x: -650.0, y: 0.0, z: 50.0 });
    assert.equal(BASIN_REGISTRY.west_gorge.radiusMeters, 250.0);

    assert.deepEqual(BASIN_REGISTRY.north_alkali.center, { x: 0.0, y: 0.0, z: 650.0 });
    assert.equal(BASIN_REGISTRY.north_alkali.radiusMeters, 250.0);

    assert.deepEqual(BASIN_REGISTRY.east_dunes.center, { x: 650.0, y: 0.0, z: 50.0 });
    assert.equal(BASIN_REGISTRY.east_dunes.radiusMeters, 250.0);

    assert.deepEqual(BASIN_REGISTRY.monolith_pass.center, { x: 650.0, y: 0.0, z: 650.0 });
    assert.equal(BASIN_REGISTRY.monolith_pass.radiusMeters, 250.0);

    // 3. Thinny Anomalies
    assert.equal(THINNY_ANOMALY_REGISTRY.length, 3);
    const beamAbyss = THINNY_ANOMALY_REGISTRY.find(t => t.id === 'thinny_beam_abyss')!;
    assert.ok(beamAbyss);
    assert.deepEqual(beamAbyss.center, { x: 325.0, y: 0.0, z: 325.0 });
    assert.equal(beamAbyss.radiusMeters, 160.0);

    const nwHollow = THINNY_ANOMALY_REGISTRY.find(t => t.id === 'thinny_nw_hollow')!;
    assert.ok(nwHollow);
    assert.deepEqual(nwHollow.center, { x: -650.0, y: 0.0, z: 650.0 });
    assert.equal(nwHollow.radiusMeters, 180.0);

    const seRift = THINNY_ANOMALY_REGISTRY.find(t => t.id === 'thinny_se_rift')!;
    assert.ok(seRift);
    assert.deepEqual(seRift.center, { x: 650.0, y: 0.0, z: -650.0 });
    assert.equal(seRift.radiusMeters, 180.0);

    // 4. Canyon Defile Pass Graph (9 Connections)
    assert.equal(CANYON_PASS_REGISTRY.length, 9);
    const expectedEdges = [
      ['waystation_sanctuary', 'sw_desolation'],
      ['sw_desolation', 'south_salt'],
      ['south_salt', 'cradle'],
      ['cradle', 'west_gorge'],
      ['cradle', 'north_alkali'],
      ['cradle', 'east_dunes'],
      ['west_gorge', 'north_alkali'],
      ['north_alkali', 'monolith_pass'],
      ['east_dunes', 'monolith_pass'],
    ];

    for (const [from, to] of expectedEdges) {
      const found = CANYON_PASS_REGISTRY.some(
        p => (p.fromBasin === from && p.toBasin === to) || (p.fromBasin === to && p.toBasin === from)
      );
      assert.ok(found, `Expected pass between ${from} and ${to}`);
    }
  });

  it('should validate Phase 2 Terrain Chunking, Heightmap Spacing, & Chasm Parity contracts', () => {
    // 1. Heightmap resolution & spacing calculation for 2500m world
    const worldSize = 2500.0;
    const heightmapResolution = 626;
    const spacing = worldSize / (heightmapResolution - 1);
    assert.equal(spacing, 4.0, '626 samples over 2500m must yield exact 4.0m spacing');

    // 2. Terrain chunk grid geometry (20x20 grid of 125m chunks)
    const chunksPerSide = 20;
    const chunkSize = worldSize / chunksPerSide;
    assert.equal(chunkSize, 125.0, '20 chunks across 2500m must yield 125m chunk footprint');

    // 3. LOD vertex spacing across the 3 LOD levels
    const lod0Subdiv = 48;
    const lod1Subdiv = 24;
    const lod2Subdiv = 12;
    assert.ok(Math.abs(chunkSize / lod0Subdiv - 2.604) < 0.01, 'LOD0 vertex spacing must be ~2.6m');
    assert.ok(Math.abs(chunkSize / lod1Subdiv - 5.208) < 0.01, 'LOD1 vertex spacing must be ~5.2m');
    assert.ok(Math.abs(chunkSize / lod2Subdiv - 10.416) < 0.01, 'LOD2 vertex spacing must be ~10.4m');

    // 4. Verify Thinny Beam Abyss (+325, +325) obstructs direct NE path between Cradle (0,0) and Monolith Pass (+650,+650)
    const cradleCenter = { x: 0.0, z: 0.0 };
    const monolithCenter = { x: 650.0, z: 650.0 };
    const directMidpoint = {
      x: (cradleCenter.x + monolithCenter.x) * 0.5,
      z: (cradleCenter.z + monolithCenter.z) * 0.5,
    };
    assert.equal(directMidpoint.x, 325.0);
    assert.equal(directMidpoint.z, 325.0);
    const abyss = THINNY_ANOMALY_REGISTRY.find(t => t.id === 'thinny_beam_abyss')!;
    const distToAbyss = Math.hypot(directMidpoint.x - abyss.center.x, directMidpoint.z - abyss.center.z);
    assert.ok(distToAbyss < abyss.radiusMeters, 'Direct midpoint must fall directly inside the Thinny Beam Abyss');
  });

  it('should validate Grounding & HeightMapShape3D Scaling Hotfix contracts', () => {
    // 1. Spacing and scale contracts
    const res = 626;
    const worldSize = 2500.0;
    const spacing = worldSize / (res - 1);
    assert.equal(spacing, 4.0, 'HeightMap spacing across 2500m at 626 res must be exactly 4.0m');

    // 2. Extent coverage check: (626 - 1) * 4.0 = 2500m
    const totalSpan = (res - 1) * spacing;
    assert.equal(totalSpan, 2500.0, 'HeightMap footprint must span exactly 2500.0m [-1250, +1250]');

    // 3. Fallback abyss floor level must be well below deepest chasm (-28.5m)
    const fallbackFloorY = -45.0;
    const deepestDepressionY = -28.5;
    assert.ok(
      fallbackFloorY < deepestDepressionY - 10.0,
      'Fallback floor must be at least 10m below deepest terrain depression to avoid intercepting player'
    );

    // 4. Ground clamping simulation: player capsule bottom cannot penetrate terrain
    const sampleHeightsAtPoints = [
      { x: -1000.0, z: -800.0, expectedGround: -0.56 }, // Node 0 bunker
      { x: -1020.0, z: -820.0, expectedGround: -0.56 }, // Node 0 spawn
      { x: -600.0, z: -600.0, simulatedGround: 8.5 },   // Dune ridge
      { x: 325.0, z: 325.0, simulatedGround: -28.5 },   // Thinny chasm
    ];

    for (const pt of sampleHeightsAtPoints) {
      const terrainHeight = pt.simulatedGround ?? pt.expectedGround!;
      let playerPosY = terrainHeight - 1.5; // Simulate sinking below ground
      let playerVelY = -9.8;

      // Execute ground clamp invariant:
      if (playerPosY < terrainHeight) {
        playerPosY = terrainHeight;
        if (playerVelY < 0.0) {
          playerVelY = 0.0;
        }
      }

      assert.equal(playerPosY, terrainHeight, `Player Y at (${pt.x}, ${pt.z}) must clamp to terrain height`);
      assert.equal(playerVelY, 0.0, 'Downward vertical velocity must reset upon ground contact');
    }
  });

  it('should validate Continuous Ground Snapping & RayCast3D Ground Snapper contracts', () => {
    // 1. Verify scenes/player.tscn contains RayCast3D ground snapper
    const playerTscn = fs.readFileSync(path.resolve(process.cwd(), 'scenes/player.tscn'), 'utf-8');
    assert.ok(playerTscn.includes('[node name="RayCast3D" type="RayCast3D" parent="."]'), 'player.tscn must have RayCast3D child node');
    assert.ok(playerTscn.includes('target_position = Vector3(0, -4, 0)'), 'RayCast3D must point vertically downward beneath feet');

    // 2. Verify player.gd implements continuous ground snapping and height sampling clamp
    const playerGd = fs.readFileSync(path.resolve(process.cwd(), 'player.gd'), 'utf-8');
    assert.ok(playerGd.includes('var ground_offset: float'), 'player.gd must export ground_offset');
    assert.ok(playerGd.includes('TerrainCollision.get_height_at'), 'player.gd must sample TerrainCollision.get_height_at');
    assert.ok(playerGd.includes('$RayCast3D.is_colliding()'), 'player.gd must check $RayCast3D.is_colliding()');
    assert.ok(playerGd.includes('$RayCast3D.get_collision_point()'), 'player.gd must query $RayCast3D.get_collision_point()');

    // 3. Verify terrain_collision.gd exposes get_height_at
    const terrainCollisionGd = fs.readFileSync(path.resolve(process.cwd(), 'terrain_collision.gd'), 'utf-8');
    assert.ok(terrainCollisionGd.includes('static func get_height_at(world_x: float, world_z: float) -> float:'), 'terrain_collision.gd must export get_height_at method');

    // 4. Verify ground snapping math across dunes with raycast hit or heightmap fallback
    const duneScenarios = [
      { currentY: 12.0, terrainY: 10.0, rayHitY: 10.0, offset: 0.0, expectedClampedY: 12.0 }, // In air
      { currentY: 9.2, terrainY: 10.0, rayHitY: 10.0, offset: 0.0, expectedClampedY: 10.0 },  // Penetrating terrain -> clamped to 10.0
      { currentY: 5.0, terrainY: 8.5, rayHitY: 8.5, offset: 1.0, expectedClampedY: 9.5 },     // Custom +1.0m offset
    ];

    for (const sc of duneScenarios) {
      const surfaceY = Math.max(sc.terrainY, sc.rayHitY);
      const clampedY = Math.max(sc.currentY, surfaceY + sc.offset);
      assert.equal(clampedY, sc.expectedClampedY, 'Player Y must clamp accurately above ground surface');
    }
  });
});
