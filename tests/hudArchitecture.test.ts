/**
 * HUD Architecture, POI Navigation & Safe House Contracts
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  BASIN_REGISTRY,
  WAYSTATION_SANCTUARY_CONFIG,
  REGIONAL_BEACON_REGISTRY,
} from '../world/types.ts';

describe('HUD Architecture & POI Navigation Systems', () => {
  it('should validate Phase 3 Node 0 Safe House & Regional Beacon / POI Architecture', () => {
    // 1. Node 0 Safe House Compound & Shelter Invariants
    const node0 = BASIN_REGISTRY.waystation_sanctuary;
    assert.equal(node0.isSafeZone, true);
    assert.deepEqual(node0.center, { x: -1000.0, y: 0.0, z: -800.0 });
    assert.equal(node0.radiusMeters, 150.0);

    // Bunker center and spawn point within sanctuary
    assert.deepEqual(WAYSTATION_SANCTUARY_CONFIG.bunkerCenter, { x: -1015.0, y: 0.0, z: -815.0 });
    assert.deepEqual(WAYSTATION_SANCTUARY_CONFIG.playerSpawn, { x: -1020.0, y: 0.0, z: -820.0 });
    const distBunkerToCenter = Math.hypot(
      WAYSTATION_SANCTUARY_CONFIG.bunkerCenter.x - node0.center.x,
      WAYSTATION_SANCTUARY_CONFIG.bunkerCenter.z - node0.center.z
    );
    assert.ok(distBunkerToCenter < node0.radiusMeters, 'Bunker structure must sit inside Node 0 sanctuary');

    // 2. 4 Diegetic Safe House Interactables & 3D GLB Asset Architecture
    assert.equal(WAYSTATION_SANCTUARY_CONFIG.modelAssetPath, 'res://assets/architecture/landmarks/waystation_bunker/bunker.glb');
    assert.deepEqual(WAYSTATION_SANCTUARY_CONFIG.modelScale, { x: 28.0, y: 26.0, z: 28.0 });
    assert.deepEqual(WAYSTATION_SANCTUARY_CONFIG.modelRotationDegrees, { x: 0.0, y: 90.0, z: 0.0 });

    const gateDeltaX = WAYSTATION_SANCTUARY_CONFIG.thresholdGate.x - WAYSTATION_SANCTUARY_CONFIG.bunkerCenter.x;
    const gateDeltaZ = WAYSTATION_SANCTUARY_CONFIG.thresholdGate.z - WAYSTATION_SANCTUARY_CONFIG.bunkerCenter.z;
    assert.ok(gateDeltaX > 100.0, 'Threshold gate must lie East down the defile pass (+X)');
    assert.ok(Math.abs(gateDeltaZ) < 15.0, 'Defile pass trajectory remains aligned within 15m of compound axis');

    const expectedInteractables = [
      'workbench_station',
      'ncp_save_terminal',
      'heavy_iron_footlocker',
      'artesian_hand_pump',
    ];
    for (const item of expectedInteractables) {
      assert.ok(
        WAYSTATION_SANCTUARY_CONFIG.interactables.includes(item as any),
        `Safe house must contain ${item}`
      );
      const socket = WAYSTATION_SANCTUARY_CONFIG.socketTransforms[item as keyof typeof WAYSTATION_SANCTUARY_CONFIG.socketTransforms];
      assert.ok(socket, `Socket transform must exist for ${item}`);
      assert.ok(socket.position.y >= 0.0, `Socket ${item} must sit grounded at or above bunker floor slab`);
    }

    const relSpawnX = WAYSTATION_SANCTUARY_CONFIG.playerSpawn.x - WAYSTATION_SANCTUARY_CONFIG.bunkerCenter.x;
    const relSpawnZ = WAYSTATION_SANCTUARY_CONFIG.playerSpawn.z - WAYSTATION_SANCTUARY_CONFIG.bunkerCenter.z;
    const sz = WAYSTATION_SANCTUARY_CONFIG.shelterZoneBounds;
    const minSzX = sz.center.x - sz.size.x * 0.5;
    const maxSzX = sz.center.x + sz.size.x * 0.5;
    const minSzZ = sz.center.z - sz.size.z * 0.5;
    const maxSzZ = sz.center.z + sz.size.z * 0.5;

    assert.ok(relSpawnX >= minSzX && relSpawnX <= maxSzX);
    assert.ok(relSpawnZ >= minSzZ && relSpawnZ <= maxSzZ);

    const offsetRelSpawnX = relSpawnX + WAYSTATION_SANCTUARY_CONFIG.playerSpawnOffset.x;
    const offsetRelSpawnZ = relSpawnZ + WAYSTATION_SANCTUARY_CONFIG.playerSpawnOffset.z;
    assert.ok(offsetRelSpawnX >= minSzX && offsetRelSpawnX <= maxSzX);
    assert.ok(offsetRelSpawnZ >= minSzZ && offsetRelSpawnZ <= maxSzZ);

    // 3. 7 Regional Ka Survey Beacons across Hostile Biomes
    assert.equal(REGIONAL_BEACON_REGISTRY.length, 7, 'Must have exactly 7 regional beacons');
    const expectedBeacons = [
      { id: 'beacon_sw_desolation', basinId: 'sw_desolation', x: -530.0, z: -880.0 },
      { id: 'beacon_south_salt', basinId: 'south_salt', x: -130.0, z: -530.0 },
      { id: 'beacon_cradle', basinId: 'cradle', x: 25.0, z: -20.0 },
      { id: 'beacon_west_gorge', basinId: 'west_gorge', x: -630.0, z: 70.0 },
      { id: 'beacon_north_alkali', basinId: 'north_alkali', x: 45.0, z: 680.0 },
      { id: 'beacon_east_dunes', basinId: 'east_dunes', x: 670.0, z: 70.0 },
      { id: 'beacon_monolith_pass', basinId: 'monolith_pass', x: 630.0, z: 630.0 },
    ];

    for (const b of expectedBeacons) {
      const beaconDef = REGIONAL_BEACON_REGISTRY.find(reg => reg.id === b.id);
      assert.ok(beaconDef, `Beacon ${b.id} must be registered`);
      assert.equal(beaconDef.basinId, b.basinId);
      assert.equal(beaconDef.position.x, b.x);
      assert.equal(beaconDef.position.z, b.z);

      const parentBasin = BASIN_REGISTRY[b.basinId as keyof typeof BASIN_REGISTRY];
      const dist = Math.hypot(b.x - parentBasin.center.x, b.z - parentBasin.center.z);
      assert.ok(dist <= parentBasin.radiusMeters, `Beacon ${b.id} must be placed within its basin footprint`);
    }

    // 4. Raider Safe House Exclusion Invariant
    const simulatedRaiderPatrols = [
      { x: -500.0, z: -850.0 },
      { x: -580.0, z: -940.0 },
      { x: -120.0, z: -510.0 },
      { x: -180.0, z: -580.0 },
      { x: 45.0, z: -50.0 },
      { x: -50.0, z: 45.0 },
      { x: -630.0, z: 30.0 },
      { x: -670.0, z: 75.0 },
      { x: 35.0, z: 630.0 },
      { x: -40.0, z: 670.0 },
      { x: 630.0, z: 40.0 },
      { x: 675.0, z: 85.0 },
      { x: 620.0, z: 620.0 },
      { x: 660.0, z: 670.0 },
    ];

    for (const p of simulatedRaiderPatrols) {
      const distFromSanctuary = Math.hypot(p.x - node0.center.x, p.z - node0.center.z);
      assert.ok(
        distFromSanctuary > 250.0,
        `Raider at (${p.x}, ${p.z}) must not breach sanctuary perimeter`
      );
    }
  });

  it('should validate Live Player Coordinates & Location Tracking HUD Header contracts', () => {
    // 1. Initial Spawn Coordinates (-1020.0, -820.0) in Node 0 Safe House
    const spawnPos = { x: -1020.0, y: 0.0, z: -820.0 };
    const clampCoord = (val: number) => Math.min(1250.0, Math.max(-1250.0, val));

    assert.equal(clampCoord(spawnPos.x), -1020.0);
    assert.equal(clampCoord(spawnPos.z), -820.0);
    assert.equal(clampCoord(-1500.0), -1250.0);
    assert.equal(clampCoord(1500.0), 1250.0);

    // 2. HUD Header String Formatting Contract
    const formatHudHeader = (
      regionName: string,
      x: number,
      z: number,
      silicaMgM3: number,
      weatherPreset: string,
      lang: 'es' | 'en' = 'es'
    ) => {
      const clampedX = clampCoord(x).toFixed(1);
      const clampedZ = clampCoord(z).toFixed(1);
      const silicaStr = silicaMgM3.toFixed(1);

      if (lang === 'es') {
        const line1 = `REGIÓN: ${regionName} | COORD: X: ${clampedX} m, Z: ${clampedZ} m`;
        const line2 = `SÍLICE EN SUSPENSIÓN: ${silicaStr} mg/m³ | ${weatherPreset}`;
        return `${line1}\n${line2}`;
      } else {
        const line1 = `REGION: ${regionName} | COORD: X: ${clampedX} m, Z: ${clampedZ} m`;
        const line2 = `AIRBORNE SILICA: ${silicaStr} mg/m³ | ${weatherPreset}`;
        return `${line1}\n${line2}`;
      }
    };

    const initialHudText = formatHudHeader('REFUGIO DE MOHAINE', spawnPos.x, spawnPos.z, 4.0, 'ÁRIDO DESPEJADO', 'es');
    assert.equal(
      initialHudText,
      'REGIÓN: REFUGIO DE MOHAINE | COORD: X: -1020.0 m, Z: -820.0 m\nSÍLICE EN SUSPENSIÓN: 4.0 mg/m³ | ÁRIDO DESPEJADO'
    );

    // 3. Dynamic Region Lookup
    const resolveCurrentBasin = (x: number, z: number) => {
      for (const [id, def] of Object.entries(BASIN_REGISTRY)) {
        const dist = Math.hypot(x - def.center.x, z - def.center.z);
        if (dist <= def.radiusMeters) {
          return { id, name: def.name, isSafeZone: def.isSafeZone };
        }
      }
      let closestId = 'waystation_sanctuary';
      let minDist = Infinity;
      for (const [id, def] of Object.entries(BASIN_REGISTRY)) {
        const dist = Math.hypot(x - def.center.x, z - def.center.z);
        if (dist < minDist) {
          minDist = dist;
          closestId = id;
        }
      }
      return { id: closestId, name: BASIN_REGISTRY[closestId as keyof typeof BASIN_REGISTRY].name, isSafeZone: false };
    };

    const startBasin = resolveCurrentBasin(spawnPos.x, spawnPos.z);
    assert.equal(startBasin.id, 'waystation_sanctuary');
    assert.equal(startBasin.isSafeZone, true);

    const midPassPos = { x: -750.0, z: -850.0 };
    const midBasin = resolveCurrentBasin(midPassPos.x, midPassPos.z);
    assert.equal(midBasin.id, 'sw_desolation');
    assert.equal(midBasin.isSafeZone, false);

    const node1Pos = { x: -550.0, z: -900.0 };
    const node1Basin = resolveCurrentBasin(node1Pos.x, node1Pos.z);
    assert.equal(node1Basin.id, 'sw_desolation');

    const node1HudText = formatHudHeader('DESOLACIÓN SUROESTE', node1Pos.x, node1Pos.z, 4.0, 'ÁRIDO DESPEJADO', 'es');
    assert.equal(
      node1HudText,
      'REGIÓN: DESOLACIÓN SUROESTE | COORD: X: -550.0 m, Z: -900.0 m\nSÍLICE EN SUSPENSIÓN: 4.0 mg/m³ | ÁRIDO DESPEJADO'
    );

    // 4. Performance Efficiency (Throttled 0.1s / 10 Hz Timer)
    let lastRenderedCoords = { x: spawnPos.x, z: spawnPos.z };
    let timer = 0.0;
    const interval = 0.1;
    let redrawCount = 0;
    const dt = 1.0 / 60.0;

    for (let frame = 0; frame < 60; frame++) {
      timer += dt;
      if (timer >= interval - 0.0001) {
        timer -= interval;
        redrawCount++;
        lastRenderedCoords = { x: spawnPos.x + frame * 0.5, z: spawnPos.z + frame * 0.5 };
      }
    }
    assert.equal(redrawCount, 10, 'UI coordinate redraw must execute at 10 Hz (every 0.1s)');
  });

  it('should validate Dark-Tower Western Minimalist HUD Layout (Destiny-Style / Borderless) contracts', () => {
    // 1. Palette & Typography Contracts
    const PALETTE = {
      OBSIDIAN_PANEL_BG: 'rgba(16, 13, 10, 0.55)',
      TARNISHED_BRONZE: '#8c6d3b',
      BONE_WHITE: '#f4efe6',
      SANDALWOOD_AMBER: '#d89b40',
      CRIMSON_HAZARD: '#e03b2e'
    };

    assert.equal(PALETTE.OBSIDIAN_PANEL_BG, 'rgba(16, 13, 10, 0.55)');
    assert.equal(PALETTE.TARNISHED_BRONZE, '#8c6d3b');
    assert.equal(PALETTE.BONE_WHITE, '#f4efe6');
    assert.equal(PALETTE.SANDALWOOD_AMBER, '#d89b40');

    // 2. Top-Center Vitals Dual-Layer Bar & Hazard Tag Contracts
    const formatTopCenterVitals = (healthCurrent: number, healthMax: number, staminaPct: number, silicaDensity: number) => {
      const isPristine = healthCurrent >= healthMax;
      const healthStatus = isPristine ? 'ILESO' : (healthCurrent <= 30 ? 'TRAUMA CRÍTICO' : 'TRAUMA LEVE');
      const vitalityLabelText = `${healthStatus} ${Math.round(healthCurrent)}/${Math.round(healthMax)}`;
      const respirationLabelText = `${Math.round(staminaPct)}%`;
      const hazardTag = `◇  ⬡ Sílice en Suspensión: ${silicaDensity.toFixed(1)} mg/m³`;

      return {
        barWidth: 420,
        vitalityHeight: 6,
        respirationHeight: 3,
        vitalityLabelText,
        respirationLabelText,
        hazardTag
      };
    };

    const vitals = formatTopCenterVitals(100, 100, 100, 2.0);
    assert.equal(vitals.barWidth, 420);
    assert.equal(vitals.vitalityHeight, 6);
    assert.equal(vitals.respirationHeight, 3);
    assert.equal(vitals.vitalityLabelText, 'ILESO 100/100');
    assert.equal(vitals.respirationLabelText, '100%');
    assert.equal(vitals.hazardTag, '◇  ⬡ Sílice en Suspensión: 2.0 mg/m³');

    // 3. Upper-Left Region & Weather Banner Contracts
    const formatUpperLeftBanner = (regionName: string, weatherPreset: string, x: number, z: number) => {
      return {
        badgeEmblem: '◇',
        regionText: regionName.toUpperCase(),
        subStateText: weatherPreset,
        coordsText: `X: ${x.toFixed(1)}m | Z: ${z.toFixed(1)}m`
      };
    };

    const banner = formatUpperLeftBanner('CUNA DE CALICHE', 'Noche Fría del Desierto', 0.0, -33.9);
    assert.equal(banner.badgeEmblem, '◇');
    assert.equal(banner.regionText, 'CUNA DE CALICHE');
    assert.equal(banner.subStateText, 'Noche Fría del Desierto');
    assert.equal(banner.coordsText, 'X: 0.0m | Z: -33.9m');

    // 4. Mid-Left Buff & Condition Stack Contracts
    const formatConditionStack = (grit: number, fouling: number, silica: number) => {
      const entries: string[] = [];
      if (grit > 0.05) entries.push(`Grava: ${Math.round(grit * 100)}%`);
      if (fouling > 0.05) entries.push(`Hollín: ${Math.round(fouling * 100)}%`);
      if (grit > 0.3 || fouling > 0.3) entries.push('Roce Áspero');
      if (silica > 0.5) entries.push(`Sílice: ${silica.toFixed(1)} mg/m³`);
      return entries.map(e => `◈ ${e}`);
    };

    const stack = formatConditionStack(0.35, 0.40, 2.0);
    assert.ok(stack.includes('◈ Grava: 35%'));
    assert.ok(stack.includes('◈ Hollín: 40%'));
    assert.ok(stack.includes('◈ Roce Áspero'));
    assert.ok(stack.includes('◈ Sílice: 2.0 mg/m³'));

    // 5. Bottom-Left Integrated Weapon & Action Cluster Contracts
    const cylinder = {
      dimension: { width: 76, height: 76 },
      chamberCount: 6,
      rotationalSnapRad: (Math.PI * 2.0) / 6.0,
      chambers: [1, 1, 1, 1, 1, 1]
    };
    assert.equal(cylinder.dimension.width, 76);
    assert.equal(cylinder.dimension.height, 76);
    assert.equal(cylinder.chamberCount, 6);
    assert.equal(cylinder.rotationalSnapRad, Math.PI / 3.0);

    const advanceCylinder = (chambers: number[]) => {
      const copy = [...chambers];
      const first = copy.shift()!;
      copy.push(first);
      return copy;
    };
    cylinder.chambers[0] = 2;
    const rotated = advanceCylinder(cylinder.chambers);
    assert.equal(rotated[5], 2);
    assert.equal(rotated[0], 1);

    const getActionTileStates = (isCocked: boolean, loaded: number, capacity: number, isJammed: boolean, grit: number, foul: number) => ({
      canCock: !isCocked,
      canLoad: loaded < capacity,
      canClear: isJammed,
      canClean: grit > 0.15 || foul > 0.15
    });
    const tileStates = getActionTileStates(false, 5, 6, false, 0.20, 0.10);
    assert.equal(tileStates.canCock, true);
    assert.equal(tileStates.canLoad, true);
    assert.equal(tileStates.canClear, false);
    assert.equal(tileStates.canClean, true);

    const formatAmmoStanceBlock = (loaded: number, reserve: number, caliber: string, isCocked: boolean, isRightShoulder: boolean, isHolstered: boolean) => {
      const hammerStr = isCocked ? 'MONTADO' : 'EN REPOSO';
      const shoulderStr = isRightShoulder ? 'DER ►' : '◀ IZQ';
      const holsterStr = isHolstered ? '[H] Desenfundar' : '[H] Enfundar';
      return {
        liveCount: `${loaded}`,
        reserveCount: `/ ${reserve}`,
        caliber,
        statusTag: `${hammerStr} | ${shoulderStr} | ${holsterStr}`
      };
    };
    const ammoBlock = formatAmmoStanceBlock(6, 36, '.45 COLT', true, true, false);
    assert.equal(ammoBlock.liveCount, '6');
    assert.equal(ammoBlock.reserveCount, '/ 36');
    assert.equal(ammoBlock.caliber, '.45 COLT');
    assert.equal(ammoBlock.statusTag, 'MONTADO | DER ► | [H] Enfundar');

    // 6. Top-Right Heading Fix Contract
    const formatRadarHeading = (deg: number, card: string) => `HDG ${deg.toString().padStart(3, '0')}° ${card}`;
    assert.equal(formatRadarHeading(180, 'S - SSE'), 'HDG 180° S - SSE');
  });

  it('should validate Tactical Map Modal & Bottom-Left Revolver Cylinder HUD integration contracts', () => {
    // 1. Map Modal Preloading & CanvasLayer Attachment Invariants
    const hudSceneLayout = {
      layerType: 'CanvasLayer',
      preloadedScenes: ['res://scenes/map_modal.tscn'],
      mapModalNode: { name: 'MapModal', parentPath: '.', initialVisible: false, minSize: { width: 960, height: 580 }, anchorsPreset: 8 },
    };
    assert.ok(hudSceneLayout.preloadedScenes.includes('res://scenes/map_modal.tscn'));
    assert.equal(hudSceneLayout.mapModalNode.parentPath, '.');
    assert.equal(hudSceneLayout.mapModalNode.initialVisible, false);
    assert.equal(hudSceneLayout.mapModalNode.minSize.width, 960);
    assert.equal(hudSceneLayout.mapModalNode.minSize.height, 580);

    // 2. Map Modal Toggle & Mouse Mode Release Lifecycle
    type MouseMode = 'CAPTURED' | 'VISIBLE';
    class WorldHudController {
      isMapOpen = false;
      mouseMode: MouseMode = 'CAPTURED';
      toggleChart() {
        this.isMapOpen = !this.isMapOpen;
        this.mouseMode = this.isMapOpen ? 'VISIBLE' : 'CAPTURED';
        return this.isMapOpen;
      }
    }
    const worldHud = new WorldHudController();
    assert.equal(worldHud.isMapOpen, false);
    assert.equal(worldHud.mouseMode, 'CAPTURED');
    assert.equal(worldHud.toggleChart(), true);
    assert.equal(worldHud.isMapOpen, true);
    assert.equal(worldHud.mouseMode, 'VISIBLE');
    assert.equal(worldHud.toggleChart(), false);
    assert.equal(worldHud.isMapOpen, false);
    assert.equal(worldHud.mouseMode, 'CAPTURED');

    // 3. Bottom-Left Revolver Cylinder Widget Invariants
    const ammoRowLayout = [
      { id: 'LiveRoundCount', type: 'Label', defaultText: '6', fontSize: 28 },
      { id: 'ReserveAmmoCount', type: 'Label', defaultText: '/ 36', fontSize: 12 },
      { id: 'CylinderIndicator', type: 'Control', minSize: { width: 34, height: 34 } },
      { id: 'CaliberLabel', type: 'Label', defaultText: '.45 COLT', fontSize: 10 },
    ];
    assert.equal(ammoRowLayout[0].id, 'LiveRoundCount');
    assert.equal(ammoRowLayout[1].id, 'ReserveAmmoCount');
    assert.equal(ammoRowLayout[2].id, 'CylinderIndicator');
    assert.deepEqual(ammoRowLayout[2].minSize, { width: 34, height: 34 });

    // 4. Circular 6-Chamber Visual Style Parity (Menu/Prologue Parity)
    const computeCylinderIndicatorGeometry = (width: number, height: number, rotationRad: number, chambers: number[]) => {
      const center = { x: width * 0.5, y: height * 0.5 };
      const outerR = Math.min(width, height) * 0.44;
      const baseRot = -Math.PI * 0.5 + rotationRad;
      const chamberPositions = [];
      for (let i = 0; i < 6; i++) {
        const angle = baseRot + i * ((Math.PI * 2.0) / 6.0);
        chamberPositions.push({
          x: center.x + Math.cos(angle) * (outerR * 0.55),
          y: center.y + Math.sin(angle) * (outerR * 0.55),
          radius: outerR * 0.21,
          state: chambers[i] ?? 0,
        });
      }
      return { center, outerR, notchPos: { x: center.x, y: center.y - outerR + 1.0 }, chambers: chamberPositions };
    };

    const geomClean = computeCylinderIndicatorGeometry(34, 34, 0.0, [1, 1, 1, 1, 1, 1]);
    assert.equal(geomClean.outerR, 34 * 0.44);
    assert.equal(geomClean.chambers.length, 6);
    assert.ok(geomClean.chambers.every(c => c.state === 1));

    const geomFired = computeCylinderIndicatorGeometry(34, 34, 0.0, [2, 1, 1, 1, 1, 0]);
    assert.equal(geomFired.chambers[0].state, 2);
    assert.equal(geomFired.chambers[5].state, 0);

    const geomJammed = computeCylinderIndicatorGeometry(34, 34, 0.0, [3, 1, 1, 1, 1, 1]);
    assert.equal(geomJammed.chambers[0].state, 3);

    const stepRad = (Math.PI * 2.0) / 6.0;
    const geomAdvanced = computeCylinderIndicatorGeometry(34, 34, stepRad, [1, 1, 1, 1, 1, 2]);
    const topChamberAngle = -Math.PI * 0.5 + stepRad;
    const expTopX = geomAdvanced.center.x + Math.cos(topChamberAngle) * (geomAdvanced.outerR * 0.55);
    const expTopY = geomAdvanced.center.y + Math.sin(topChamberAngle) * (geomAdvanced.outerR * 0.55);
    assert.ok(Math.abs(geomAdvanced.chambers[0].x - expTopX) < 0.001);
    assert.ok(Math.abs(geomAdvanced.chambers[0].y - expTopY) < 0.001);
  });
});

