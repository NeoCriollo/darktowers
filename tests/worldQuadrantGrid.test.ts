/**
 * World Quadrant Grid & POI World-Mapping System Tests
 * Validates 4x4 16-Quadrant World Grid, Elevation Relief, and POI Mapping
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  QUADRANT_GRID_CONFIG,
  QUADRANT_DEFINITIONS,
  getQuadrantForPosition,
  getQuadrantById,
  getAllQuadrants,
  getAllRegisteredPOIs,
  getPOIsForQuadrant,
  generateAsciiMap,
  type QuadrantId,
} from '../world/worldQuadrantGrid.ts';

describe('World Quadrant Grid & POI Topographic Mapping', () => {
  it('should validate 4x4 16-quadrant coordinate space and geometric bounds', () => {
    // 1. Grid geometry configuration
    assert.equal(QUADRANT_GRID_CONFIG.GRID_COLUMNS, 4);
    assert.equal(QUADRANT_GRID_CONFIG.GRID_ROWS, 4);
    assert.equal(QUADRANT_GRID_CONFIG.QUADRANT_COUNT, 16);
    assert.equal(QUADRANT_GRID_CONFIG.QUADRANT_SIZE_M, 625.0);
    assert.equal(QUADRANT_GRID_CONFIG.WORLD_MIN_X, -1250.0);
    assert.equal(QUADRANT_GRID_CONFIG.WORLD_MAX_X, 1250.0);
    assert.equal(QUADRANT_GRID_CONFIG.WORLD_MIN_Z, -1250.0);
    assert.equal(QUADRANT_GRID_CONFIG.WORLD_MAX_Z, 1250.0);

    // 2. All 16 quadrants must exist and have correct bounds
    const quads = getAllQuadrants();
    assert.equal(quads.length, 16);

    for (let i = 1; i <= 16; i++) {
      const qId = `Q${String(i).padStart(2, '0')}` as QuadrantId;
      const q = getQuadrantById(qId);
      assert.ok(q, `Quadrant ${qId} must exist`);
      assert.equal(q.id, qId);

      const col = q.colIndex;
      const row = q.rowIndex;
      const expectedCode = `${QUADRANT_GRID_CONFIG.COL_CODES[col]}${QUADRANT_GRID_CONFIG.ROW_CODES[row]}`;
      assert.equal(q.code, expectedCode);

      // Verify bounds
      const expectedMinX = -1250.0 + col * 625.0;
      const expectedMaxX = expectedMinX + 625.0;
      const expectedMinZ = -1250.0 + row * 625.0;
      const expectedMaxZ = expectedMinZ + 625.0;

      assert.equal(q.bounds.minX, expectedMinX);
      assert.equal(q.bounds.maxX, expectedMaxX);
      assert.equal(q.bounds.minZ, expectedMinZ);
      assert.equal(q.bounds.maxZ, expectedMaxZ);
      assert.equal(q.bounds.sizeMeters, 625.0);
      assert.equal(q.bounds.centerX, (expectedMinX + expectedMaxX) * 0.5);
      assert.equal(q.bounds.centerZ, (expectedMinZ + expectedMaxZ) * 0.5);
    }
  });

  it('should validate topographic relief profile and elevation bounds per quadrant', () => {
    // Q01: Mohaine Sanctuary (0m displacement at bunker, encircling ridges)
    const q01 = getQuadrantById('Q01');
    assert.ok(q01.elevation.minElevationM < 0.0);
    assert.ok(q01.elevation.maxElevationM >= 10.0, 'Sanctuary perimeter ridge rises above +10m');
    assert.ok(q01.elevation.reliefDeltaM > 12.0);

    // Q06: Dead-Creek Salt Flats (low playa floor)
    const q06 = getQuadrantById('Q06');
    assert.ok(q06.elevation.minElevationM < -3.0);
    assert.ok(q06.elevation.maxElevationM > 20.0, 'Salt pan ringed by perimeter ridges');

    // Q09 & Q10: Rust-Gorge Defile (high canyon walls > +25m)
    const q09 = getQuadrantById('Q09');
    const q10 = getQuadrantById('Q10');
    assert.ok(q09.elevation.maxElevationM >= 26.0, 'Gorge canyon wall peaks above +26m');
    assert.ok(q10.elevation.maxElevationM >= 26.0, 'Defile pass reaches peak mesa elevation');

    // Q11: Caliche Cradle & Thinny Beam Abyss (deepest depression ~ -30m)
    const q11 = getQuadrantById('Q11');
    assert.ok(q11.elevation.minElevationM <= -28.0, 'Thinny Abyss chasm plunges to -28m or lower');
    assert.ok(q11.elevation.reliefDeltaM >= 45.0, 'Cradle has highest relief delta in game world');

    // Q12: The Great Shifting Erg (high-amplitude mega-dunes)
    const q12 = getQuadrantById('Q12');
    assert.ok(q12.elevation.maxElevationM >= 18.0, 'Mega-dune razor crests rise above +18m');

    // Q16: Tower Threshold & The Dark Tower Spire
    const q16 = getQuadrantById('Q16');
    assert.ok(q16.elevation.maxElevationM >= 8.5, 'Stepped volcanic basalt terraces reach +9m');
  });

  it('should accurately resolve world coordinates to quadrants', () => {
    // 1. Starting spawn & Sanctuary
    const spawnQ = getQuadrantForPosition(-1020.0, -820.0);
    assert.equal(spawnQ.id, 'Q01');
    assert.equal(spawnQ.code, 'A1');

    const gateQ = getQuadrantForPosition(-900.0, -820.0);
    assert.equal(gateQ.id, 'Q01');

    // 2. Biome Centers
    assert.equal(getQuadrantForPosition(-550.0, -900.0).id, 'Q02'); // SW Desolation
    assert.equal(getQuadrantForPosition(-150.0, -550.0).id, 'Q06'); // Dead-Creek Salt
    assert.equal(getQuadrantForPosition(-650.0, 50.0).id, 'Q09');   // Rust-Gorge
    assert.equal(getQuadrantForPosition(650.0, 50.0).id, 'Q12');    // East Dunes
    assert.equal(getQuadrantForPosition(650.0, 650.0).id, 'Q16');   // Monolith Pass
    assert.equal(getQuadrantForPosition(700.0, 700.0).id, 'Q16');   // Dark Tower Spire

    // 3. Thinny Anomalies
    assert.equal(getQuadrantForPosition(325.0, 325.0).id, 'Q11');   // Beam Abyss
    assert.equal(getQuadrantForPosition(-650.0, 650.0).id, 'Q13');  // NW Hollow
    assert.equal(getQuadrantForPosition(650.0, -650.0).id, 'Q04');  // SE Rift

    // 4. Clamping bounds
    assert.equal(getQuadrantForPosition(-2000.0, -2000.0).id, 'Q01');
    assert.equal(getQuadrantForPosition(2000.0, 2000.0).id, 'Q16');
  });

  it('should validate comprehensive POI registry mapping across all quadrants', () => {
    const allPois = getAllRegisteredPOIs();
    assert.ok(allPois.length >= 40, `Registry must contain comprehensive POIs (found ${allPois.length})`);

    // Verify critical POIs exist
    const spawnPoi = allPois.find(p => p.id === 'poi_waystation_interior');
    assert.ok(spawnPoi);
    assert.equal(spawnPoi.quadrantId, 'Q01');

    const spirePoi = allPois.find(p => p.id === 'dark_tower_spire');
    assert.ok(spirePoi);
    assert.equal(spirePoi.quadrantId, 'Q16');

    const abyssPoi = allPois.find(p => p.id === 'thinny_beam_abyss');
    assert.ok(abyssPoi);
    assert.equal(abyssPoi.quadrantId, 'Q11');

    // Verify all 7 beacons are in registered list
    const beacons = allPois.filter(p => p.category === 'BEACON');
    assert.equal(beacons.length, 7);

    // Verify getPOIsForQuadrant filtering
    const q01Pois = getPOIsForQuadrant('Q01');
    assert.ok(q01Pois.some(p => p.id === 'poi_waystation_interior'));
    assert.ok(q01Pois.some(p => p.id === 'poi_threshold_warning_gate'));

    const q09Pois = getPOIsForQuadrant('Q09');
    assert.ok(q09Pois.some(p => p.id === 'gorge_overpass_slab_1'));
    assert.ok(q09Pois.some(p => p.id === 'beacon_west_gorge'));
  });

  it('should produce structured ASCII map with all 16 quadrants represented', () => {
    const ascii = generateAsciiMap();
    assert.ok(ascii.includes('TOPOGRAPHIC QUADRANT GRID'));
    for (let i = 1; i <= 16; i++) {
      const qId = `Q${String(i).padStart(2, '0')}`;
      assert.ok(ascii.includes(qId), `ASCII map must render ${qId}`);
    }
  });
});

