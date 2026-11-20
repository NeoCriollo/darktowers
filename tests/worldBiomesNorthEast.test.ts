/**
 * North-East Wasteland Biomes Integration Tests (Node 4 - Node 7)
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { WeatherEngine } from '../world/weather.ts';
import {
  BASIN_REGISTRY,
  WEST_GORGE_CONFIG,
  NORTH_ALKALI_CONFIG,
  EAST_DUNES_CONFIG,
  TOWER_THRESHOLD_CONFIG,
} from '../world/types.ts';

const smoothstep = (e0: number, e1: number, x: number): number => {
  const t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
};

describe('North-East Wasteland Biomes (Nodes 4 - 7)', () => {
  it('should validate Node 4 (Rust-Gorge Defile) bounds, canyon floor vs cliff wall elevation delta, and iron-oxide hazard contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = WEST_GORGE_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, -800.0);
    assert.equal(bounds.maxX, -400.0);
    assert.equal(bounds.minZ, -100.0);
    assert.equal(bounds.maxZ, 400.0);

    const node4 = BASIN_REGISTRY.west_gorge;
    assert.equal(node4.center.x, -650.0);
    assert.equal(node4.center.z, 50.0);
    assert.ok(node4.connectedBasinIds.includes('cradle'));
    assert.ok(node4.connectedBasinIds.includes('north_alkali'));

    // 2. Heightmap canyon floor vs cliff wall sculpting
    const evaluateGorgeMask = (wx: number, wz: number) => {
      const gorgeXMask = smoothstep(-850.0, -750.0, wx) * (1.0 - smoothstep(-450.0, -350.0, wx));
      const gorgeZMask = smoothstep(-150.0, -50.0, wz) * (1.0 - smoothstep(350.0, 450.0, wz));
      return gorgeXMask * gorgeZMask;
    };

    assert.equal(evaluateGorgeMask(-1020.0, -820.0), 0.0, 'Gorge mask must have 0 effect at sanctuary');
    assert.equal(evaluateGorgeMask(-650.0, 50.0), 1.0, 'Gorge core center must have full gorge mask');

    const evaluateGorgeRelief = (wx: number, wz: number) => {
      const mask = evaluateGorgeMask(wx, wz);
      const corridorX = -650.0 + 45.0 * Math.sin(wz * 0.018) + 20.0 * Math.cos(wz * 0.040);
      const latDist = Math.abs(wx - corridorX);

      const floorH = -0.65;
      const wallT = Math.max(0, Math.min(1, (latDist - 24.0) / 44.0));
      const wallSmooth = wallT * wallT * (3.0 - 2.0 * wallT);
      const ledgeStep = Math.floor(wallSmooth * 4.0) / 4.0;
      const cliffH = (wallSmooth * 0.60 + ledgeStep * 0.40) * 18.5;

      const passEast = smoothstep(-480.0, -410.0, wx);
      return ((floorH + cliffH) * (1.0 - passEast * 0.55)) * mask;
    };

    const wz = 50.0;
    const corridorCenter = -650.0 + 45.0 * Math.sin(wz * 0.018) + 20.0 * Math.cos(wz * 0.040);
    const canyonFloorDelta = evaluateGorgeRelief(corridorCenter, wz);
    const cliffWallDelta = evaluateGorgeRelief(corridorCenter - 68.0, wz);

    assert.ok(canyonFloorDelta < 0.0, `Canyon corridor floor must be depressed (got: ${canyonFloorDelta.toFixed(2)}m)`);
    assert.ok(cliffWallDelta > 15.0, `Cliff wall top must rise tall (got: ${cliffWallDelta.toFixed(2)}m)`);
    const elevationDelta = cliffWallDelta - canyonFloorDelta;
    assert.ok(elevationDelta > 14.0, `Canyon floor vs cliff wall elevation delta must exceed 12m (got: ${elevationDelta.toFixed(2)}m)`);

    // 3. Atmosphere & Hazard Tuning
    const envParams = WEST_GORGE_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#473833', 'Cool dusty dark iron-oxide shadow fog color');
    assert.equal(envParams.fogDensity, 0.022);
    assert.equal(envParams.volumetricFogDensity, 0.035);
    assert.equal(envParams.sunEnergy, 1.15);
    assert.equal(envParams.sunVisibility, 0.65);
    assert.equal(envParams.ironOxideMultiplier, 1.8);
    assert.equal(envParams.silicaAccumulationMultiplier, 1.8);
    assert.equal(envParams.weatherTone, 'RUST_GORGE_SHADOW');

    const weather = new WeatherEngine('CLEAR_ARID');
    assert.equal(weather.getEffectiveFoulingMultiplier(), 1.0);
    assert.equal(weather.getEffectiveFoulingMultiplier('west_gorge'), 1.8);
    const baseGrit = weather.currentAtmosphere.gritSuspensionDensityMgM3;
    assert.equal(weather.getEffectiveGritDensity('west_gorge'), baseGrit * 1.8);

    // 4. Prop & Landmark Scattering
    assert.equal(WEST_GORGE_CONFIG.landmarks.length, 6, 'Must feature 6 landmark structures in Rust-Gorge Defile');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;
    let overpassCount = 0;
    let pipelineCount = 0;

    for (const lm of WEST_GORGE_CONFIG.landmarks) {
      if (lm.type === 'COLLAPSED_OVERPASS') overpassCount++;
      if (lm.type === 'CORRODED_PIPELINE') pipelineCount++;
      assert.ok(lm.position.x >= bounds.minX && lm.position.x <= bounds.maxX);
      assert.ok(lm.position.z >= bounds.minZ && lm.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(lm.position.x - node0RefugeCenter.x, lm.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Landmark ${lm.id} must remain outside Node 0 refuge`);
    }
    assert.equal(overpassCount, 3);
    assert.equal(pipelineCount, 3);
  });

  it('should validate Node 5 (Bleached Alkali Sink & Ka Beacon Monolith) bounds, concave saucer profile, and Ka resonance hazard contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = NORTH_ALKALI_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, -300.0);
    assert.equal(bounds.maxX, 300.0);
    assert.equal(bounds.minZ, 400.0);
    assert.equal(bounds.maxZ, 900.0);

    const node5 = BASIN_REGISTRY.north_alkali;
    assert.equal(node5.center.x, 0.0);
    assert.equal(node5.center.z, 650.0);
    assert.ok(node5.connectedBasinIds.includes('cradle'));
    assert.ok(node5.connectedBasinIds.includes('west_gorge'));
    assert.ok(node5.connectedBasinIds.includes('monolith_pass'));

    // 2. Heightmap saucer basin & amphitheater rim contracts
    const evaluateAlkaliMask = (wx: number, wz: number) => {
      const alkaliXMask = smoothstep(-350.0, -250.0, wx) * (1.0 - smoothstep(250.0, 350.0, wx));
      const alkaliZMask = smoothstep(350.0, 450.0, wz) * (1.0 - smoothstep(850.0, 950.0, wz));
      return alkaliXMask * alkaliZMask;
    };

    assert.equal(evaluateAlkaliMask(-1020.0, -820.0), 0.0, 'Alkali mask must have 0 effect at sanctuary');
    assert.equal(evaluateAlkaliMask(-150.0, -550.0), 0.0, 'Alkali mask must have 0 effect at South Salt');
    assert.equal(evaluateAlkaliMask(0.0, 650.0), 1.0, 'Alkali core center must have full mask');

    const evaluateAlkaliRelief = (wx: number, wz: number) => {
      const mask = evaluateAlkaliMask(wx, wz);
      const dBasin = Math.hypot(wx, wz - 650.0);
      const panDip = (1.0 - smoothstep(0.0, 160.0, dBasin)) * -1.8;
      const rimT = smoothstep(140.0, 220.0, dBasin) * (1.0 - smoothstep(250.0, 320.0, dBasin));
      const badlandHills = rimT * 6.5;

      const dMonolith = Math.hypot(wx - 45.0, wz - 680.0);
      const padSmooth = 1.0 - smoothstep(8.0, 22.0, dMonolith);
      const rawAlkali = panDip + badlandHills;
      return (rawAlkali * (1.0 - padSmooth) + -1.2 * padSmooth) * mask;
    };

    assert.equal(evaluateAlkaliRelief(0.0, 650.0), -1.8, 'Central basin pan floor must dip to -1.8m');
    assert.equal(evaluateAlkaliRelief(45.0, 680.0), -1.2, 'Monolith foundation pad must sit level at -1.2m');

    const rimElevation = evaluateAlkaliRelief(0.0, 850.0);
    assert.ok(rimElevation >= 4.5 && rimElevation <= 8.5, `Badland rim must rise between +4.5m and +8.5m`);
    const saucerDelta = rimElevation - evaluateAlkaliRelief(0.0, 650.0);
    assert.ok(saucerDelta > 5.0, `Concave saucer relief delta must exceed 5.0m`);

    // 3. Atmosphere & Alkali / Ka Resonance Hazard Tuning
    const envParams = NORTH_ALKALI_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#e0dcc2');
    assert.equal(envParams.fogDensity, 0.015);
    assert.equal(envParams.volumetricFogDensity, 0.025);
    assert.equal(envParams.sunEnergy, 2.4);
    assert.equal(envParams.sunVisibility, 1.0);
    assert.equal(envParams.saltCorrosionMultiplier, 2.0);
    assert.equal(envParams.kaBeaconResonanceMultiplier, 1.0);
    assert.equal(envParams.weatherTone, 'BLEACHED_ALKALI_SINK');

    const weather = new WeatherEngine('CLEAR_ARID');
    assert.equal(weather.getEffectiveCorrosionMultiplier('north_alkali'), 2.0);
    assert.equal(weather.getEffectiveKaResonance({ x: 0.0, z: 0.0 }), 0.0);
    assert.equal(weather.getEffectiveKaResonance({ x: 45.0, z: 680.0 }), 1.0);
    assert.ok(Math.abs(weather.getEffectiveKaResonance({ x: 45.0, z: 740.0 }) - 0.50) < 0.01);
    assert.equal(weather.getEffectiveKaResonance({ x: 45.0, z: 810.0 }), 0.0);

    // 4. Prop & Landmark Scattering
    assert.equal(NORTH_ALKALI_CONFIG.landmarks.length, 6, 'Must feature 6 landmark structures in Bleached Alkali Sink');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;
    let beaconCount = 0;
    let plinthCount = 0;
    let conduitCount = 0;
    let moundCount = 0;

    for (const lm of NORTH_ALKALI_CONFIG.landmarks) {
      if (lm.type === 'KA_BEACON_MONOLITH') beaconCount++;
      if (lm.type === 'MONOLITH_PLINTH') plinthCount++;
      if (lm.type === 'POWER_CONDUIT') conduitCount++;
      if (lm.type === 'MINERAL_MOUND') moundCount++;
      assert.ok(lm.position.x >= bounds.minX && lm.position.x <= bounds.maxX);
      assert.ok(lm.position.z >= bounds.minZ && lm.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(lm.position.x - node0RefugeCenter.x, lm.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Landmark ${lm.id} must remain outside Node 0 refuge`);
    }
    assert.equal(beaconCount, 1);
    assert.equal(plinthCount, 1);
    assert.equal(conduitCount, 2);
    assert.equal(moundCount, 2);
  });

  it('should validate Node 6 (The Great Shifting Erg & Old-Ones Megastructure Ruin) bounds, mega-dune relief, stamina/silica hazards, and ruin landmark contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = EAST_DUNES_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, 400.0);
    assert.equal(bounds.maxX, 900.0);
    assert.equal(bounds.minZ, -300.0);
    assert.equal(bounds.maxZ, 300.0);

    const node6 = BASIN_REGISTRY.east_dunes;
    assert.equal(node6.center.x, 650.0);
    assert.equal(node6.center.z, 50.0);
    assert.ok(node6.connectedBasinIds.includes('cradle'));
    assert.ok(node6.connectedBasinIds.includes('monolith_pass'));

    // 2. Heightmap mega-dune sculpting & trough-to-crest elevation contracts
    const evaluateEastDunesMask = (wx: number, wz: number) => {
      const eastXMask = smoothstep(350.0, 450.0, wx) * (1.0 - smoothstep(850.0, 950.0, wx));
      const eastZMask = smoothstep(-350.0, -250.0, wz) * (1.0 - smoothstep(250.0, 350.0, wz));
      return eastXMask * eastZMask;
    };

    assert.equal(evaluateEastDunesMask(-1020.0, -820.0), 0.0, 'East dunes mask must have 0 effect at sanctuary');
    assert.equal(evaluateEastDunesMask(650.0, 50.0), 1.0, 'East dunes core center must have full mask');

    const wx_wind = Math.cos(0.78);
    const wz_wind = Math.sin(0.78);
    const evaluateDuneRelief = (wx: number, wz: number, forceCrestPhase?: number) => {
      const mask = evaluateEastDunesMask(wx, wz);
      const windU = wx * wx_wind + wz * wz_wind;
      const dunePhase = forceCrestPhase !== undefined ? forceCrestPhase : windU * 0.024;
      const sharpCrest = 1.0 - Math.abs(Math.sin(dunePhase));
      const asymCrest = Math.pow(sharpCrest, 1.35) * (1.0 + 0.25 * Math.cos(dunePhase));
      const clampedAsym = Math.max(0.0, Math.min(1.0, asymCrest));
      const rawDune = -2.0 * (1.0 - clampedAsym) + 14.5 * clampedAsym;

      const dRuin = Math.hypot(wx - 680.0, wz - (-20.0));
      const scoopFactor = 1.0 - smoothstep(12.0, 44.0, dRuin);
      const seatedDune = rawDune * (1.0 - scoopFactor * 0.70) + 1.8 * (scoopFactor * 0.70);
      return seatedDune * mask;
    };

    const troughRelief = evaluateDuneRelief(650.0, 50.0, Math.PI * 0.5);
    const crestRelief = evaluateDuneRelief(650.0, 50.0, 0.0);
    assert.ok(troughRelief <= -1.5, `Interdune trough must dip deep (got: ${troughRelief.toFixed(2)}m)`);
    assert.ok(crestRelief >= 10.0, `Mega-dune crest must tower high (got: ${crestRelief.toFixed(2)}m)`);
    assert.ok(crestRelief - troughRelief > 10.0, `Trough-to-crest relief delta must exceed 10.0m`);

    const ruinRelief = evaluateDuneRelief(680.0, -20.0, 0.0);
    assert.ok(ruinRelief < crestRelief - 5.0, `Wind-scoop pocket must be scooped lower than crest`);

    // 3. Atmosphere & Loose-Sand Stamina / Silica Hazard Tuning
    const envParams = EAST_DUNES_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#bf9e73');
    assert.equal(envParams.fogDensity, 0.006);
    assert.equal(envParams.volumetricFogDensity, 0.009);
    assert.equal(envParams.sunEnergy, 2.65);
    assert.equal(envParams.sunVisibility, 1.0);
    assert.equal(envParams.silicaAccumulationMultiplier, 2.2);
    assert.equal(envParams.staminaDrainMultiplier, 1.6);
    assert.equal(envParams.weatherTone, 'GREAT_SHIFTING_ERG');

    const weather = new WeatherEngine('CLEAR_ARID');
    const baseGrit = weather.currentAtmosphere.gritSuspensionDensityMgM3;
    assert.equal(weather.getEffectiveGritDensity('east_dunes'), baseGrit * 2.2);
    assert.equal(weather.getEffectiveStaminaDrainMultiplier('east_dunes'), 1.6);
    assert.equal(weather.getEffectiveStaminaDrainMultiplier('cradle'), 1.0);

    // 4. Prop & Landmark Scattering
    assert.equal(EAST_DUNES_CONFIG.landmarks.length, 6, 'Must feature 6 landmark structures in The Great Shifting Erg');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;
    let ruinCount = 0;
    let gantryCount = 0;
    let pylonCount = 0;

    for (const lm of EAST_DUNES_CONFIG.landmarks) {
      if (lm.type === 'OLD_ONES_MEGASTRUCTURE') ruinCount++;
      if (lm.type === 'GANTRY_STRUT') gantryCount++;
      if (lm.type === 'OBSIDIAN_PYLON') pylonCount++;
      assert.ok(lm.position.x >= bounds.minX && lm.position.x <= bounds.maxX);
      assert.ok(lm.position.z >= bounds.minZ && lm.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(lm.position.x - node0RefugeCenter.x, lm.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Landmark ${lm.id} must remain outside Node 0 refuge`);
    }
    assert.equal(ruinCount, 3);
    assert.equal(gantryCount, 2);
    assert.equal(pylonCount, 1);
  });

  it('should validate Node 7 (Tower Threshold & Citadel Perimeter) bounds, basalt terraces, Tower strain, and fortification contracts', () => {
    // 1. Quadrant bounds & coordinate architecture
    const bounds = TOWER_THRESHOLD_CONFIG.quadrantBounds;
    assert.equal(bounds.minX, 400.0);
    assert.equal(bounds.maxX, 900.0);
    assert.equal(bounds.minZ, 400.0);
    assert.equal(bounds.maxZ, 900.0);

    const node7 = BASIN_REGISTRY.monolith_pass;
    assert.equal(node7.center.x, 650.0);
    assert.equal(node7.center.z, 650.0);
    assert.ok(node7.connectedBasinIds.includes('north_alkali'));
    assert.ok(node7.connectedBasinIds.includes('east_dunes'));

    // 2. Heightmap basalt terrace sculpting & elevation contracts
    const evaluateTowerMask = (wx: number, wz: number) => {
      const towerXMask = smoothstep(350.0, 480.0, wx) * (1.0 - smoothstep(850.0, 950.0, wx));
      const towerZMask = smoothstep(350.0, 480.0, wz) * (1.0 - smoothstep(850.0, 950.0, wz));
      return towerXMask * towerZMask;
    };

    assert.equal(evaluateTowerMask(-1020.0, -820.0), 0.0, 'Refuge safe house must have 0.0 tower mask');
    assert.ok(evaluateTowerMask(700.0, 700.0) > 0.99, 'Citadel center mask must be ~1.0');

    const citadelElevation = TOWER_THRESHOLD_CONFIG.citadelPlateauElevation;
    const fissureElevation = TOWER_THRESHOLD_CONFIG.fissureTroughElevation;
    const elevationDelta = citadelElevation - fissureElevation;
    assert.ok(elevationDelta >= 8.0, `Elevation delta must be >= 8.0m (got: ${elevationDelta}m)`);

    // 3. Atmosphere & Tower Nexus Strain Proximity Hazard
    const envParams = TOWER_THRESHOLD_CONFIG.environmentalParameters;
    assert.equal(envParams.fogColorHex, '#47080a', 'Blood-crimson storm fog');
    assert.equal(envParams.fogDensity, 0.018);
    assert.equal(envParams.volumetricFogDensity, 0.032);
    assert.equal(envParams.sunEnergy, 1.95);
    assert.equal(envParams.sunVisibility, 0.85);
    assert.equal(envParams.silicaAccumulationMultiplier, 2.4);
    assert.equal(envParams.towerNexusStrainMultiplier, 1.0);
    assert.equal(envParams.weatherTone, 'BLOOD_CRIMSON_STORM');

    const weather = new WeatherEngine('CLEAR_ARID');
    const baseGrit = weather.currentAtmosphere.gritSuspensionDensityMgM3;
    assert.equal(weather.getEffectiveGritDensity('monolith_pass'), baseGrit * 2.4);
    assert.equal(weather.getEffectiveGritDensity('tower_threshold'), baseGrit * 2.4);

    assert.equal(weather.getEffectiveTowerNexusStrain({ x: 700.0, z: 700.0 }), 1.0);
    assert.ok(Math.abs(weather.getEffectiveTowerNexusStrain({ x: 700.0, z: 810.0 }) - 0.5) < 0.001);
    assert.equal(weather.getEffectiveTowerNexusStrain({ x: 450.0, z: 450.0 }), 0.0);
    assert.equal(weather.getEffectiveTowerNexusStrain(undefined), 0.0);

    // 4. Prop & Landmark Scattering
    assert.equal(TOWER_THRESHOLD_CONFIG.landmarks.length, 6, 'Must feature 6 landmark structures in Tower Threshold');
    const node0RefugeCenter = BASIN_REGISTRY.waystation_sanctuary.center;
    let spireCount = 0;
    let hedgehogCount = 0;
    let wireCount = 0;
    let wreckCount = 0;

    for (const lm of TOWER_THRESHOLD_CONFIG.landmarks) {
      if (lm.type === 'DARK_TOWER_SPIRE') spireCount++;
      if (lm.type === 'CZECH_HEDGEHOG') hedgehogCount++;
      if (lm.type === 'CONCERTINA_WIRE') wireCount++;
      if (lm.type === 'ARMORED_WRECK') wreckCount++;
      assert.ok(lm.position.x >= bounds.minX && lm.position.x <= bounds.maxX);
      assert.ok(lm.position.z >= bounds.minZ && lm.position.z <= bounds.maxZ);
      const distToRefuge = Math.hypot(lm.position.x - node0RefugeCenter.x, lm.position.z - node0RefugeCenter.z);
      assert.ok(distToRefuge > 250.0, `Landmark ${lm.id} must remain outside Node 0 refuge`);
    }
    assert.equal(spireCount, 1);
    assert.equal(hedgehogCount, 2);
    assert.equal(wireCount, 1);
    assert.equal(wreckCount, 2);
  });
});

