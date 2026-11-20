/**
 * South-West Wasteland Biomes Integration Tests (Node 0 - Node 3)
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { WeatherEngine } from '../world/weather.ts';
import { WeaponMechanics } from '../physics/weaponMechanics.ts';
import { WORLD_CONFIG } from '../core/config.ts';
import {
  BASIN_REGISTRY,
  SW_DESOLATION_CONFIG,
  SOUTH_SALT_CONFIG,
  CRADLE_NEXUS_CONFIG,
} from '../world/types.ts';

const smoothstep = (e0: number, e1: number, x: number): number => {
  const t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
};

describe('South-West Wasteland Biomes (Nodes 0 - 3)', () => {
  it('should validate Node 0 (waystation_sanctuary) initial spawn & new game checkpoint contracts', () => {
    // 1. Mandatory spawn position at Node 0 hangar
    const hangarSpawn = WORLD_CONFIG.INITIAL_PLAYER_SPAWN;
    assert.equal(hangarSpawn.x, -1020.0);
    assert.equal(hangarSpawn.z, -820.0);

    // 2. Initial spawn must reside within the Node 0 safe house boundary
    const node0 = BASIN_REGISTRY.waystation_sanctuary;
    const distToNode0Center = Math.hypot(hangarSpawn.x - node0.center.x, hangarSpawn.z - node0.center.z);
    assert.ok(distToNode0Center <= node0.radiusMeters, 'Spawn must be inside Node 0 refuge radius');

    // 3. New Game / legacy save validation logic
    interface SaveState {
      hasSaveFile: boolean;
      hasExplicitOutsideSave: boolean;
      savedPosition?: { x: number; y: number; z: number };
      savedSector?: string;
    }

    const resolveSpawn = (save: SaveState) => {
      if (!save.hasSaveFile || !save.hasExplicitOutsideSave || !save.savedPosition) {
        return { ...hangarSpawn, sector: 'waystation_sanctuary', checkpoint: 'The Mohaine Way-Bunker' };
      }
      return { ...save.savedPosition, sector: save.savedSector || 'waystation_sanctuary' };
    };

    // Case A: Fresh new game (no save) -> Hangar
    const newGameSpawn = resolveSpawn({ hasSaveFile: false, hasExplicitOutsideSave: false });
    assert.equal(newGameSpawn.x, -1020.0);
    assert.equal(newGameSpawn.z, -820.0);
    assert.equal(newGameSpawn.sector, 'waystation_sanctuary');

    // Case B: Legacy / corrupted save with Caliche Cradle (0, 0) and no explicit outside flag -> Hangar
    const legacySaveSpawn = resolveSpawn({
      hasSaveFile: true,
      hasExplicitOutsideSave: false,
      savedPosition: { x: 0.0, y: 0.0, z: 0.0 },
      savedSector: 'cradle'
    });
    assert.equal(legacySaveSpawn.x, -1020.0);
    assert.equal(legacySaveSpawn.z, -820.0);
    assert.equal(legacySaveSpawn.sector, 'waystation_sanctuary');

    // Case C: Explicit save made outside in the wasteland (e.g. Sw Desolation) -> Honored
    const explicitSaveSpawn = resolveSpawn({
      hasSaveFile: true,
      hasExplicitOutsideSave: true,
      savedPosition: { x: -550.0, y: 1.0, z: -900.0 },
      savedSector: 'sw_desolation'
    });
    assert.equal(explicitSaveSpawn.x, -550.0);
    assert.equal(explicitSaveSpawn.z, -900.0);
    assert.equal(explicitSaveSpawn.sector, 'sw_desolation');
  });

  it('should validate Node 1 (SW Desolation) visual concept sculpting, atmospheric tuning, and scavenge node contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = SW_DESOLATION_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, -800.0);
    assert.equal(bounds.maxX, -400.0);
    assert.equal(bounds.minZ, -1000.0);
    assert.equal(bounds.maxZ, -600.0);

    const node1 = BASIN_REGISTRY.sw_desolation;
    assert.equal(node1.center.x, -550.0);
    assert.equal(node1.center.z, -900.0);
    assert.ok(node1.center.x >= bounds.minX && node1.center.x <= bounds.maxX);
    assert.ok(node1.center.z >= bounds.minZ && node1.center.z <= bounds.maxZ);

    // 2. Heightmap noise transform transition contracts
    const evaluateSwNoiseMask = (wx: number, wz: number) => {
      const swXMask = smoothstep(-850.0, -700.0, wx) * (1.0 - smoothstep(-450.0, -350.0, wx));
      const swZMask = smoothstep(-1050.0, -950.0, wz) * (1.0 - smoothstep(-650.0, -550.0, wz));
      const distToBunker = Math.hypot(wx - (-1000.0), wz - (-800.0));
      const bunkerClearance = smoothstep(140.0, 190.0, distToBunker);
      return swXMask * swZMask * bunkerClearance;
    };

    assert.equal(evaluateSwNoiseMask(-1020.0, -820.0), 0.0, 'SW Desolation noise must be 0 at bunker spawn');
    assert.equal(evaluateSwNoiseMask(-900.0, -820.0), 0.0, 'SW Desolation noise must be 0 at Mohaine gate');
    assert.ok(evaluateSwNoiseMask(-550.0, -900.0) > 0.85, 'SW Desolation core must exhibit full noise transform');

    // 3. Atmosphere & Hazard Tuning
    const envParams = SW_DESOLATION_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#d98a3d', 'Dense amber dust fog color');
    assert.equal(envParams.fogDensity, 0.048, 'Dense dust fog density');
    assert.equal(envParams.volumetricFogDensity, 0.072, 'Heavy volumetric particulate density');
    assert.equal(envParams.sunEnergy, 0.55, 'Low sun visibility energy level');
    assert.equal(envParams.sunVisibility, 0.40, 'Low solar visibility ratio');
    assert.equal(envParams.silicaAccumulationMultiplier, 2.5, '2.5x increased silica accumulation multiplier');
    assert.equal(envParams.weatherTone, 'AMBER_HABOOB');

    const weather = new WeatherEngine('CLEAR_ARID');
    const baseGrit = weather.currentAtmosphere.gritSuspensionDensityMgM3;
    assert.equal(weather.getEffectiveGritDensity(), baseGrit);
    assert.equal(weather.getEffectiveGritDensity('sw_desolation'), baseGrit * 2.5, 'Effective grit in SW Desolation must be 2.5x');

    // 4. Scavenge Prop Spawning
    assert.equal(SW_DESOLATION_CONFIG.scavengeNodes.length, 6, 'Must have 6 tactical scavenge scrap nodes');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;

    for (const node of SW_DESOLATION_CONFIG.scavengeNodes) {
      assert.equal(node.type, 'HARDPAN_RIDGE_BASE');
      assert.ok(node.position.x >= bounds.minX && node.position.x <= bounds.maxX);
      assert.ok(node.position.z >= bounds.minZ && node.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(node.position.x - node0RefugeCenter.x, node.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Scrap node ${node.id} must remain outside Node 0 refuge`);
    }
  });

  it('should validate Node 2 (Dead-Creek Salt Flats) playa flattening, glare atmosphere, salt corrosion, and landmark contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = SOUTH_SALT_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, -400.0);
    assert.equal(bounds.maxX, 0.0);
    assert.equal(bounds.minZ, -800.0);
    assert.equal(bounds.maxZ, -300.0);

    const node2 = BASIN_REGISTRY.south_salt;
    assert.equal(node2.center.x, -150.0);
    assert.equal(node2.center.z, -550.0);
    assert.ok(node2.center.x >= bounds.minX && node2.center.x <= bounds.maxX);
    assert.ok(node2.center.z >= bounds.minZ && node2.center.z <= bounds.maxZ);
    assert.ok(node2.connectedBasinIds.includes('sw_desolation'));
    assert.ok(node2.connectedBasinIds.includes('cradle'));

    // 2. Heightmap playa flattening contracts
    const evaluateSaltPlayaMask = (wx: number, wz: number) => {
      const saltXMask = smoothstep(-430.0, -370.0, wx) * (1.0 - smoothstep(-30.0, 30.0, wx));
      const saltZMask = smoothstep(-830.0, -770.0, wz) * (1.0 - smoothstep(-330.0, -270.0, wz));
      return saltXMask * saltZMask;
    };

    assert.equal(evaluateSaltPlayaMask(-1020.0, -820.0), 0.0, 'Salt mask must have 0 effect at bunker spawn');
    assert.equal(evaluateSaltPlayaMask(-1000.0, -800.0), 0.0, 'Salt mask must have 0 effect at sanctuary center');
    assert.equal(evaluateSaltPlayaMask(-150.0, -550.0), 1.0, 'Salt flats core center must exhibit full playa mask');

    const sampleRawHeight = (wx: number, wz: number) => Math.sin(wx * 0.01) * 4.0 + Math.cos(wz * 0.01) * 3.0;
    const rawH = sampleRawHeight(-150.0, -550.0);
    const flattenedH = rawH * (1.0 - 0.95) + SOUTH_SALT_CONFIG.playaElevation * 0.95;
    assert.ok(
      Math.abs(flattenedH - SOUTH_SALT_CONFIG.playaElevation) < 0.5,
      `Playa floor height must clamp near ${SOUTH_SALT_CONFIG.playaElevation}m`
    );

    // 3. Atmosphere & Hazard Tuning
    const envParams = SOUTH_SALT_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#eae6d6', 'Bleached bone-white dust haze color');
    assert.equal(envParams.fogDensity, 0.008);
    assert.equal(envParams.volumetricFogDensity, 0.012);
    assert.equal(envParams.sunEnergy, 2.8);
    assert.equal(envParams.sunVisibility, 1.0);
    assert.equal(envParams.glareVisibilityPenalty, 0.45);
    assert.equal(envParams.saltCorrosionMultiplier, 2.5);
    assert.equal(envParams.weatherTone, 'BLEACHED_PLAYA');

    const weather = new WeatherEngine('CLEAR_ARID');
    assert.equal(weather.getEffectiveCorrosionMultiplier(), 1.0);
    assert.equal(weather.getEffectiveCorrosionMultiplier('south_salt'), 2.5);
    assert.equal(weather.getEffectiveGlarePenalty(), 0.0);
    assert.equal(weather.getEffectiveGlarePenalty('south_salt'), 0.45);

    // Weapon mechanics salt corrosion degradation
    const weapon = new WeaponMechanics({
      id: 'six_shooter',
      modelName: 'Gunslinger Revolver',
      actionType: 'REVOLVER',
      chamberCapacity: 6,
      caliber: '.45_LONG_COLT',
      baseNominalVelocityMps: 260.0,
    });
    assert.equal(weapon.corrosionIndex, 0.0);
    weapon.exposeToSaltCorrosion(10.0, envParams.saltCorrosionMultiplier);
    assert.ok(weapon.corrosionIndex > 0.0, 'Holstered weapon receives slight salt exposure');

    weapon.isHolstered = false;
    const preDrawnLube = weapon.lubricationQuality;
    weapon.exposeToSaltCorrosion(10.0, envParams.saltCorrosionMultiplier);
    assert.ok(weapon.corrosionIndex > 0.10, 'Drawn weapon corrosion index must increase rapidly');
    assert.ok(weapon.lubricationQuality < preDrawnLube, 'Salt corrosion must break down lubrication');

    // 4. Prop & Landmark Scattering
    assert.equal(SOUTH_SALT_CONFIG.landmarks.length, 10, 'Must have 10 landmark structures in salt flats');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;
    let telegraphCount = 0;
    let skeletonCount = 0;

    for (const lm of SOUTH_SALT_CONFIG.landmarks) {
      if (lm.type === 'TELEGRAPH_POLE') telegraphCount++;
      if (lm.type === 'BLEACHED_SKELETON') skeletonCount++;
      assert.ok(lm.position.x >= bounds.minX && lm.position.x <= bounds.maxX);
      assert.ok(lm.position.z >= bounds.minZ && lm.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(lm.position.x - node0RefugeCenter.x, lm.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Landmark ${lm.id} must remain outside Node 0 refuge`);
    }
    assert.equal(telegraphCount, 6, 'Must feature 6 telegraph poles');
    assert.equal(skeletonCount, 4, 'Must feature 4 bleached skeletons');
  });

  it('should validate Node 3 (Caliche Cradle & Thinny Overlook) bounds, arroyo & cliff drop sculpting, and Thinny hazard contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = CRADLE_NEXUS_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, -200.0);
    assert.equal(bounds.maxX, 200.0);
    assert.equal(bounds.minZ, -200.0);
    assert.equal(bounds.maxZ, 200.0);

    const node3 = BASIN_REGISTRY.cradle;
    assert.equal(node3.center.x, 0.0);
    assert.equal(node3.center.z, 0.0);
    assert.ok(node3.connectedBasinIds.includes('south_salt'));
    assert.ok(node3.connectedBasinIds.includes('west_gorge'));
    assert.ok(node3.connectedBasinIds.includes('north_alkali'));
    assert.ok(node3.connectedBasinIds.includes('east_dunes'));

    // 2. Heightmap sculpting & topological transition contracts
    const evaluateCradleMask = (wx: number, wz: number) => {
      const cradleXMask = smoothstep(-250.0, -170.0, wx) * (1.0 - smoothstep(190.0, 260.0, wx));
      const cradleZMask = smoothstep(-250.0, -170.0, wz) * (1.0 - smoothstep(190.0, 260.0, wz));
      return cradleXMask * cradleZMask;
    };

    assert.equal(evaluateCradleMask(-1020.0, -820.0), 0.0, 'Cradle mask must have 0 effect at sanctuary');
    assert.equal(evaluateCradleMask(-150.0, -550.0), 0.0, 'Cradle mask must have 0 effect at South Salt');
    assert.equal(evaluateCradleMask(0.0, 0.0), 1.0, 'Cradle core center must have full cradle mask');

    const crossroadsSmooth = (wx: number, wz: number) => {
      const dCenter = Math.hypot(wx, wz);
      return 1.0 - smoothstep(28.0, 62.0, dCenter);
    };
    assert.equal(crossroadsSmooth(0.0, 0.0), 1.0, 'Central crossroads (0, 0) must be 100% smoothed');

    const evaluateCradleElevationDelta = (wx: number, wz: number) => {
      const mask = evaluateCradleMask(wx, wz);
      const dCenter = Math.hypot(wx, wz);
      const crossroads = 1.0 - smoothstep(28.0, 62.0, dCenter);
      const dOverlook = Math.hypot(wx - 140.0, wz - 140.0);
      const overlookPromontory = (1.0 - smoothstep(0.0, 48.0, dOverlook)) * 4.8;
      const abyssDirDot = (wx - 140.0) + (wz - 140.0);
      const chasmCliffDrop = smoothstep(8.0, 60.0, abyssDirDot) * 16.5;
      const raw = overlookPromontory - chasmCliffDrop;
      return (raw * (1.0 - crossroads)) * mask;
    };

    const overlookDelta = evaluateCradleElevationDelta(140.0, 140.0);
    assert.ok(overlookDelta > 4.5, `Overlook promontory at (+140, +140) must sit elevated (got: ${overlookDelta.toFixed(2)}m)`);
    const pastRimDelta = evaluateCradleElevationDelta(180.0, 180.0);
    assert.ok(pastRimDelta < -10.0, `Past overlook rim (+180, +180) must plunge down (got: ${pastRimDelta.toFixed(2)}m)`);
    assert.ok(overlookDelta - pastRimDelta > 15.0, 'Cliff drop from overlook into abyss must exceed 15m');

    // 3. Atmosphere & Thinny Proximity Hazard
    const envParams = CRADLE_NEXUS_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#adbdcf', 'Pale dusty-blue sky fog color');
    assert.equal(envParams.fogDensity, 0.007);
    assert.equal(envParams.volumetricFogDensity, 0.010);
    assert.equal(envParams.sunEnergy, 2.2);
    assert.equal(envParams.sunVisibility, 1.0);
    assert.equal(envParams.thinnyDistortionMultiplier, 1.0);
    assert.equal(envParams.weatherTone, 'CRADLE_CLEAR_AZURE');

    const weather = new WeatherEngine('CLEAR_ARID');
    assert.equal(weather.getEffectiveThinnyDistortion({ x: 0.0, z: 0.0 }), 0.0);
    assert.ok(weather.getEffectiveThinnyDistortion({ x: 110.0, z: 110.0 }) > 0.05);
    assert.equal(weather.getEffectiveThinnyDistortion({ x: 140.0, z: 140.0 }), 0.35);
    assert.ok(weather.getEffectiveThinnyDistortion({ x: 200.0, z: 200.0 }) > 0.70);
    assert.equal(weather.getEffectiveThinnyDistortion({ x: 300.0, z: 300.0 }), 1.0);

    // 4. Prop & Landmark Scattering
    assert.equal(CRADLE_NEXUS_CONFIG.landmarks.length, 8, 'Must have 8 landmark assets in Caliche Cradle');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;
    let waymarkerCount = 0;
    let overlookCount = 0;
    let scrubCount = 0;

    for (const lm of CRADLE_NEXUS_CONFIG.landmarks) {
      if (lm.type === 'STONE_WAYMARKER') waymarkerCount++;
      if (lm.type === 'SURVEY_OVERLOOK') overlookCount++;
      if (lm.type === 'DESERT_SCRUB') scrubCount++;
      assert.ok(lm.position.x >= bounds.minX && lm.position.x <= bounds.maxX);
      assert.ok(lm.position.z >= bounds.minZ && lm.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(lm.position.x - node0RefugeCenter.x, lm.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Landmark ${lm.id} must remain outside Node 0 refuge`);
    }
    assert.equal(waymarkerCount, 3);
    assert.equal(overlookCount, 2);
    assert.equal(scrubCount, 3);
  });
});

