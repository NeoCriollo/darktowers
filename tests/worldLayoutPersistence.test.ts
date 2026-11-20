/**
 * Unit Tests for World Layout Persistence & JSON Overrides (Phase 4)
 * Validates schema, coordinate boundaries, catalog asset ID checking,
 * and strict Node 0 Sanctuary Invariant enforcement.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  CURRENT_SCHEMA_VERSION,
  MAP_HALF_EXTENT,
  NODE_0_BUNKER_SPAWN,
  createEmptyLayoutOverride,
  validateLayoutSchema,
  validateNode0SanctuaryClearance,
  serializeLayoutOverrides,
  parseLayoutOverrides,
  generateEscarpmentRockId,
  generateEscarpmentCliffId,
  generateSanctuaryOutcropShelfId,
  generateSanctuaryCalicheSlabId,
  generateSanctuaryCrouchBoulderId,
  generateCastleStoneId,
  recordProceduralModification,
  applyLayoutOverridesToProceduralProps,
  reloadAndPreserveProceduralOverrides,
  type WorldLayoutOverrideData,
  type ProceduralPropNode,
  type TransformOverride
} from '../world/worldLayoutPersistence.ts';

describe('World Layout Persistence & JSON Overrides (Phase 4)', () => {
  it('should validate default empty layout override schema', () => {
    const empty = createEmptyLayoutOverride();
    assert.strictEqual(empty.version, CURRENT_SCHEMA_VERSION);
    assert.deepStrictEqual(empty.modifications, {});
    assert.deepStrictEqual(empty.deletions, []);
    assert.deepStrictEqual(empty.spawned, []);

    const res = validateLayoutSchema(empty);
    assert.strictEqual(res.valid, true);
    assert.strictEqual(res.errors.length, 0);
  });

  it('should validate modifications, deletions, and spawned asset records', () => {
    const layout: WorldLayoutOverrideData = {
      version: CURRENT_SCHEMA_VERSION,
      timestamp: '2026-11-02T18:12:00Z',
      modifications: {
        mohaine_shelf_01: {
          position: [-980.5, 2.1, -805.0],
          rotation: [0.0, 45.0, 0.0],
          scale: [3.5, 3.2, 3.5]
        }
      },
      deletions: ['caliche_rock_12', 'debris_old_04'],
      spawned: [
        {
          instance_id: 'editor_spawn_001',
          asset_id: 'monolith_pylon',
          position: [-950.0, 1.2, -780.0],
          rotation: [0.0, 15.0, 0.0],
          scale: [2.0, 2.0, 2.0]
        },
        {
          instance_id: 'editor_spawn_002',
          asset_id: 'rock_4',
          position: [620.0, 18.0, 640.0],
          rotation: [5.0, 90.0, 0.0],
          scale: [12.0, 20.0, 12.0]
        }
      ]
    };

    const res = validateLayoutSchema(layout);
    assert.strictEqual(res.valid, true);
    assert.strictEqual(res.errors.length, 0);

    const serialized = serializeLayoutOverrides(layout);
    const parsed = parseLayoutOverrides(serialized);
    assert.strictEqual(parsed.spawned.length, 2);
    assert.strictEqual(parsed.deletions.length, 2);
    assert.ok(parsed.modifications.mohaine_shelf_01);
  });

  it('should reject invalid schema versions and malformed payload types', () => {
    const invalidVersion = {
      version: '0.9.0',
      timestamp: new Date().toISOString(),
      modifications: {},
      deletions: [],
      spawned: []
    };
    const res1 = validateLayoutSchema(invalidVersion);
    assert.strictEqual(res1.valid, false);
    assert.ok(res1.errors.some((e) => e.includes('schema version')));

    const malformed = {
      version: CURRENT_SCHEMA_VERSION,
      modifications: 'not_an_object',
      deletions: null,
      spawned: 'not_an_array'
    };
    const res2 = validateLayoutSchema(malformed);
    assert.strictEqual(res2.valid, false);
    assert.ok(res2.errors.length >= 3);
  });

  it('should reject unknown catalog asset IDs in spawned records', () => {
    const unknownAssetLayout: WorldLayoutOverrideData = {
      version: CURRENT_SCHEMA_VERSION,
      timestamp: new Date().toISOString(),
      modifications: {},
      deletions: [],
      spawned: [
        {
          instance_id: 'invalid_spawn_999',
          asset_id: 'laser_satellite_cannon',
          position: [0.0, 0.0, 0.0],
          rotation: [0.0, 0.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        }
      ]
    };

    const res = validateLayoutSchema(unknownAssetLayout);
    assert.strictEqual(res.valid, false);
    assert.ok(res.errors.some((e) => e.includes("Unknown catalog asset_id 'laser_satellite_cannon'")));
  });

  it('should reject out-of-bounds coordinates exceeding +/-1250m map bounds', () => {
    const outOfBoundsLayout: WorldLayoutOverrideData = {
      version: CURRENT_SCHEMA_VERSION,
      timestamp: new Date().toISOString(),
      modifications: {
        prop_beyond_world: {
          position: [1300.0, 10.0, -500.0], // X = 1300 > 1250
          rotation: [0.0, 0.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        }
      },
      deletions: [],
      spawned: [
        {
          instance_id: 'spawn_out_of_bounds',
          asset_id: 'rock_3',
          position: [0.0, 5.0, -1450.0], // Z = -1450 < -1250
          rotation: [0.0, 0.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        }
      ]
    };

    const res = validateLayoutSchema(outOfBoundsLayout);
    assert.strictEqual(res.valid, false);
    assert.ok(res.errors.some((e) => e.includes('out of map bounds')));
  });

  it('should enforce Node 0 Sanctuary Invariant (bunker spawn & blast corridor)', () => {
    // 1. Violation: Prop directly at bunker spawn (-1020, -820)
    const bunkerViolation: WorldLayoutOverrideData = {
      version: CURRENT_SCHEMA_VERSION,
      timestamp: new Date().toISOString(),
      modifications: {},
      deletions: [],
      spawned: [
        {
          instance_id: 'bad_rock_on_bunker',
          asset_id: 'rock_2',
          position: [NODE_0_BUNKER_SPAWN.x + 1.0, 0.0, NODE_0_BUNKER_SPAWN.z],
          rotation: [0.0, 0.0, 0.0],
          scale: [3.0, 3.0, 3.0]
        }
      ]
    };
    const check1 = validateNode0SanctuaryClearance(bunkerViolation);
    assert.strictEqual(check1.clear, false);
    assert.ok(check1.violations.some((v) => v.includes('bunker spawn clearance')));

    // 2. Violation: Prop in direct blast corridor (-1120, -1120)
    const corridorViolation: WorldLayoutOverrideData = {
      version: CURRENT_SCHEMA_VERSION,
      timestamp: new Date().toISOString(),
      modifications: {
        blocking_monolith: {
          position: [-1120.0, 0.0, -1120.0],
          rotation: [0.0, 0.0, 0.0],
          scale: [2.0, 2.0, 2.0]
        }
      },
      deletions: [],
      spawned: []
    };
    const check2 = validateNode0SanctuaryClearance(corridorViolation);
    assert.strictEqual(check2.clear, false);
    assert.ok(check2.violations.some((v) => v.includes('blast-gate corridor')));

    // 3. Clear: Prop placed outside sanctuary corridor (-1120, -1090)
    const clearLayout: WorldLayoutOverrideData = {
      version: CURRENT_SCHEMA_VERSION,
      timestamp: new Date().toISOString(),
      modifications: {
        safe_flank_shelf: {
          position: [-1120.0, 0.0, -1090.0], // 30m offset from corridor
          rotation: [0.0, 0.0, 0.0],
          scale: [2.0, 2.0, 2.0]
        }
      },
      deletions: [],
      spawned: []
    };
    const check3 = validateNode0SanctuaryClearance(clearLayout);
    assert.strictEqual(check3.clear, true);
    assert.strictEqual(check3.violations.length, 0);
  });

  it('should validate the actual on-disk world_layout_overrides.json file', () => {
    const jsonPath = path.resolve('world/data/world_layout_overrides.json');
    assert.ok(fs.existsSync(jsonPath), 'world/data/world_layout_overrides.json must exist');

    const fileContent = fs.readFileSync(jsonPath, 'utf-8');
    const parsed = parseLayoutOverrides(fileContent);
    assert.strictEqual(parsed.version, CURRENT_SCHEMA_VERSION);

    const sanctuaryCheck = validateNode0SanctuaryClearance(parsed);
    assert.strictEqual(sanctuaryCheck.clear, true);
  });

  describe('Phase 6.5: Pre-Existing Procedural Prop & Override Persistence', () => {
    it('should generate deterministic stable IDs for procedural dressers (escarpments, sanctuary, castle ruins)', () => {
      assert.strictEqual(generateEscarpmentRockId(1011.5), 'EscarpmentRock_1011');
      assert.strictEqual(generateEscarpmentCliffId(2021), 'EscarpmentCliff_2021');
      assert.strictEqual(generateSanctuaryOutcropShelfId(1), 'Mohaine_OutcropShelf_1');
      assert.strictEqual(generateSanctuaryCalicheSlabId(3), 'Mohaine_CalicheSlab_3');
      assert.strictEqual(generateSanctuaryCrouchBoulderId(2), 'Mohaine_CrouchBoulder_2');
      assert.strictEqual(generateCastleStoneId(5, 'Assets 4'), 'Q01_MedievalRuin_5_Assets_4');
      assert.strictEqual(generateCastleStoneId(12, 'Base wall'), 'Q01_MedievalRuin_12_Base_wall');

      const ids = [
        generateEscarpmentRockId(1011),
        generateEscarpmentCliffId(2021),
        generateSanctuaryOutcropShelfId(1),
        generateSanctuaryCalicheSlabId(3),
        generateSanctuaryCrouchBoulderId(2),
        generateCastleStoneId(5, 'Assets 4')
      ];

      for (const id of ids) {
        assert.ok(!id.startsWith('@'), `Stable ID ${id} must not start with volatile '@'`);
        assert.ok(!id.includes(' '), `Stable ID ${id} must not contain spaces`);
      }
    });

    it('should record procedural modifications with stable UUIDs and reject volatile runtime node paths', () => {
      const layout = createEmptyLayoutOverride();

      // Should reject volatile Godot runtime names
      const volatileProp: ProceduralPropNode = {
        name: '@Node3D@1452053',
        prop_uuid: '',
        position: [-990.0, 1.0, -828.0],
        rotation: [0, 0, 0],
        scale: [1, 1, 1]
      };
      assert.throws(
        () => recordProceduralModification(layout, volatileProp, { position: [-990, 2, -828], rotation: [0, 0, 0], scale: [1, 1, 1] }),
        /volatile runtime name/
      );

      // Should record valid stable procedural prop modifications
      const castleStone: ProceduralPropNode = {
        name: 'Q01_MedievalRuin_1_Assets_1',
        prop_uuid: 'Q01_MedievalRuin_1_Assets_1',
        position: [-950.0, 0.0, -950.0],
        rotation: [0, 0, 0],
        scale: [1, 1, 1]
      };
      const escarpmentRock: ProceduralPropNode = {
        name: 'EscarpmentRock_1011',
        prop_uuid: 'EscarpmentRock_1011',
        position: [-600.0, 25.0, -700.0],
        rotation: [8.0, 45.0, 0.0],
        scale: [30.0, 37.5, 30.0]
      };

      recordProceduralModification(layout, castleStone, {
        position: [-940.0, 2.5, -945.0],
        rotation: [0.0, 90.0, 0.0],
        scale: [1.5, 1.8, 1.5]
      });
      recordProceduralModification(layout, escarpmentRock, {
        position: [-595.0, 28.0, -690.0],
        rotation: [15.0, 60.0, 0.0],
        scale: [32.0, 40.0, 32.0]
      });

      assert.strictEqual(Object.keys(layout.modifications).length, 2);
      assert.ok(layout.modifications['Q01_MedievalRuin_1_Assets_1']);
      assert.ok(layout.modifications['EscarpmentRock_1011']);

      const validation = validateLayoutSchema(layout);
      assert.strictEqual(validation.valid, true);

      const sanctuaryCheck = validateNode0SanctuaryClearance(layout);
      assert.strictEqual(sanctuaryCheck.clear, true);
    });

    it('should preserve position, rotation, and scale adjustments for castle stones and escarpment rocks upon reloading', () => {
      // 1. Initial base procedural scene generated by world dressers
      const baseProceduralScene: ProceduralPropNode[] = [
        {
          name: 'Q01_MedievalRuin_1_Assets_1',
          prop_uuid: 'Q01_MedievalRuin_1_Assets_1',
          position: [-950.0, 0.0, -950.0],
          rotation: [0.0, 0.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        },
        {
          name: 'EscarpmentRock_1011',
          prop_uuid: 'EscarpmentRock_1011',
          position: [-600.0, 25.0, -700.0],
          rotation: [8.0, 45.0, 0.0],
          scale: [30.0, 37.5, 30.0]
        },
        {
          name: 'Mohaine_OutcropShelf_1',
          prop_uuid: 'Mohaine_OutcropShelf_1',
          position: [-1015.0, 0.0, -788.0],
          rotation: [5.0, 15.0, 0.0],
          scale: [20.0, 16.0, 18.0]
        }
      ];

      // 2. Editor modifies castle stone & escarpment rock and serializes to JSON
      const layout = createEmptyLayoutOverride();
      recordProceduralModification(layout, baseProceduralScene[0], {
        position: [-942.0, 3.2, -948.0],
        rotation: [0.0, 75.0, 0.0],
        scale: [1.4, 1.6, 1.4]
      });
      recordProceduralModification(layout, baseProceduralScene[1], {
        position: [-590.0, 29.5, -695.0],
        rotation: [12.0, 50.0, 0.0],
        scale: [35.0, 42.0, 35.0]
      });

      const serialized = serializeLayoutOverrides(layout);

      // 3. Simulate game boot: Fresh procedural re-instantiation occurs FIRST
      const freshProceduralProps: ProceduralPropNode[] = [
        {
          name: 'Q01_MedievalRuin_1_Assets_1',
          prop_uuid: 'Q01_MedievalRuin_1_Assets_1',
          position: [-950.0, 0.0, -950.0], // Original base coords
          rotation: [0.0, 0.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        },
        {
          name: 'EscarpmentRock_1011',
          prop_uuid: 'EscarpmentRock_1011',
          position: [-600.0, 25.0, -700.0], // Original base coords
          rotation: [8.0, 45.0, 0.0],
          scale: [30.0, 37.5, 30.0]
        },
        {
          name: 'Mohaine_OutcropShelf_1',
          prop_uuid: 'Mohaine_OutcropShelf_1',
          position: [-1015.0, 0.0, -788.0],
          rotation: [5.0, 15.0, 0.0],
          scale: [20.0, 16.0, 18.0]
        }
      ];

      // 4. Overrides applied ON TOP of fresh procedural props
      const preservedProps = reloadAndPreserveProceduralOverrides(freshProceduralProps, serialized);

      assert.strictEqual(preservedProps.length, 3);

      // Verify castle stone retained modified adjustments
      const reloadedCastle = preservedProps.find((p) => p.prop_uuid === 'Q01_MedievalRuin_1_Assets_1')!;
      assert.deepStrictEqual(reloadedCastle.position, [-942.0, 3.2, -948.0]);
      assert.deepStrictEqual(reloadedCastle.rotation, [0.0, 75.0, 0.0]);
      assert.deepStrictEqual(reloadedCastle.scale, [1.4, 1.6, 1.4]);

      // Verify escarpment rock retained modified adjustments
      const reloadedRock = preservedProps.find((p) => p.prop_uuid === 'EscarpmentRock_1011')!;
      assert.deepStrictEqual(reloadedRock.position, [-590.0, 29.5, -695.0]);
      assert.deepStrictEqual(reloadedRock.rotation, [12.0, 50.0, 0.0]);
      assert.deepStrictEqual(reloadedRock.scale, [35.0, 42.0, 35.0]);

      // Verify un-modified sanctuary prop kept original procedural values
      const unmoddedShelf = preservedProps.find((p) => p.prop_uuid === 'Mohaine_OutcropShelf_1')!;
      assert.deepStrictEqual(unmoddedShelf.position, [-1015.0, 0.0, -788.0]);
      assert.deepStrictEqual(unmoddedShelf.rotation, [5.0, 15.0, 0.0]);
      assert.deepStrictEqual(unmoddedShelf.scale, [20.0, 16.0, 18.0]);
    });

    it('should enforce that pre-existing procedural props deleted in editor remain removed upon reloading', () => {
      const freshProps: ProceduralPropNode[] = [
        {
          name: 'Q01_MedievalRuin_2_Asstes_2',
          prop_uuid: 'Q01_MedievalRuin_2_Asstes_2',
          position: [-850.0, 0.0, -850.0],
          rotation: [0, 0, 0],
          scale: [1, 1, 1]
        },
        {
          name: 'EscarpmentRock_2021',
          prop_uuid: 'EscarpmentRock_2021',
          position: [-500.0, 20.0, -600.0],
          rotation: [0, 0, 0],
          scale: [25, 25, 25]
        }
      ];

      const layout = createEmptyLayoutOverride();
      layout.deletions.push('Q01_MedievalRuin_2_Asstes_2');
      const serialized = serializeLayoutOverrides(layout);

      const preserved = reloadAndPreserveProceduralOverrides(freshProps, serialized);
      assert.strictEqual(preserved.length, 1);
      assert.strictEqual(preserved[0].prop_uuid, 'EscarpmentRock_2021');
      assert.ok(!preserved.some((p) => p.prop_uuid === 'Q01_MedievalRuin_2_Asstes_2'));
    });
  });
});
