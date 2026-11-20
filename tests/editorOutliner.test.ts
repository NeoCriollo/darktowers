/**
 * Unit Tests for Dual-Mode Object Outliner & Hierarchy Browser Domain (Phase 6)
 * Validates sector bucketing, search filtering, focus camera offsets,
 * selection synchronization, and modification tracking.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  OUTLINER_SECTORS,
  CUSTOM_SPAWNS_SECTOR_ID,
  CUSTOM_SPAWNS_SECTOR_NAME,
  findNearestSectorZone,
  resolvePropSectorId,
  bucketPropsBySector,
  filterOutlinerProps,
  filterGroupedProps,
  calculateFocusCameraPosition,
  EditorOutlinerState,
  type OutlinerProp
} from '../world/editorOutliner.ts';

describe('Dual-Mode Object Outliner & Hierarchy Browser (Phase 6)', () => {
  const sampleProps: OutlinerProp[] = [
    {
      instanceId: 'bunker_structure_01',
      assetName: 'Mohaine Way-Bunker Shelter',
      position: { x: -1175.0, y: 0.0, z: -1170.0 }
    },
    {
      instanceId: 'desolation_scaffold_02',
      assetName: 'SW Weathered Scaffold',
      position: { x: -540.0, y: 3.5, z: -890.0 }
    },
    {
      instanceId: 'salt_flat_pole_03',
      assetName: 'Telegraph Wood Pole',
      position: { x: -160.0, y: 1.0, z: -530.0 }
    },
    {
      instanceId: 'cradle_ruin_arch_04',
      assetName: 'Caliche Stone Archway',
      position: { x: 10.0, y: 5.0, z: -15.0 }
    },
    {
      instanceId: 'rust_gorge_pipe_05',
      assetName: 'Industrial Slag Conduit',
      position: { x: -640.0, y: 12.0, z: 60.0 }
    },
    {
      instanceId: 'alkali_sink_pylon_06',
      assetName: 'Ancient Resonant Monolith',
      position: { x: -10.0, y: 8.0, z: 660.0 }
    },
    {
      instanceId: 'erg_sand_crawler_07',
      assetName: 'Old-Ones Sand Harvester',
      position: { x: 640.0, y: 22.0, z: 45.0 }
    },
    {
      instanceId: 'dark_tower_spire_08',
      assetName: 'Tower Basalt Buttress',
      position: { x: 660.0, y: 40.0, z: 640.0 }
    },
    {
      instanceId: 'custom_spawn_gothic_gate',
      assetName: 'Custom Gothic Iron Gate',
      position: { x: -1150.0, y: 2.0, z: -1150.0 },
      isCustom: true
    }
  ];

  it('should validate all 8 canonical wasteland sector zone definitions', () => {
    assert.strictEqual(OUTLINER_SECTORS.length, 8);
    assert.strictEqual(OUTLINER_SECTORS[0].id, 'node_0');
    assert.strictEqual(OUTLINER_SECTORS[0].hubX, -1180.0);
    assert.strictEqual(OUTLINER_SECTORS[0].hubZ, -1180.0);
    assert.strictEqual(OUTLINER_SECTORS[7].id, 'node_7');
    assert.strictEqual(OUTLINER_SECTORS[7].hubX, 650.0);
    assert.strictEqual(OUTLINER_SECTORS[7].hubZ, 650.0);
    assert.strictEqual(CUSTOM_SPAWNS_SECTOR_ID, 'custom_spawns');
    assert.strictEqual(CUSTOM_SPAWNS_SECTOR_NAME, 'Custom Spawns / Overrides');
  });

  it('should accurately resolve nearest sector zone from 2D coordinates', () => {
    // Exact hub positions
    assert.strictEqual(findNearestSectorZone(-1180.0, -1180.0).id, 'node_0');
    assert.strictEqual(findNearestSectorZone(-550.0, -900.0).id, 'node_1');
    assert.strictEqual(findNearestSectorZone(-150.0, -550.0).id, 'node_2');
    assert.strictEqual(findNearestSectorZone(0.0, 0.0).id, 'node_3');
    assert.strictEqual(findNearestSectorZone(-650.0, 50.0).id, 'node_4');
    assert.strictEqual(findNearestSectorZone(0.0, 650.0).id, 'node_5');
    assert.strictEqual(findNearestSectorZone(650.0, 50.0).id, 'node_6');
    assert.strictEqual(findNearestSectorZone(650.0, 650.0).id, 'node_7');

    // Nearby points
    assert.strictEqual(findNearestSectorZone(-1100.0, -1150.0).id, 'node_0');
    assert.strictEqual(findNearestSectorZone(600.0, 700.0).id, 'node_7');
  });

  it('should correctly bucket props into respective sector zones and custom bucket', () => {
    const buckets = bucketPropsBySector(sampleProps);

    // Each node should have received its corresponding sample prop
    assert.strictEqual(buckets.node_0.length, 1);
    assert.strictEqual(buckets.node_0[0].instanceId, 'bunker_structure_01');

    assert.strictEqual(buckets.node_1.length, 1);
    assert.strictEqual(buckets.node_1[0].instanceId, 'desolation_scaffold_02');

    assert.strictEqual(buckets.node_2.length, 1);
    assert.strictEqual(buckets.node_2[0].instanceId, 'salt_flat_pole_03');

    assert.strictEqual(buckets.node_3.length, 1);
    assert.strictEqual(buckets.node_3[0].instanceId, 'cradle_ruin_arch_04');

    assert.strictEqual(buckets.node_4.length, 1);
    assert.strictEqual(buckets.node_4[0].instanceId, 'rust_gorge_pipe_05');

    assert.strictEqual(buckets.node_5.length, 1);
    assert.strictEqual(buckets.node_5[0].instanceId, 'alkali_sink_pylon_06');

    assert.strictEqual(buckets.node_6.length, 1);
    assert.strictEqual(buckets.node_6[0].instanceId, 'erg_sand_crawler_07');

    assert.strictEqual(buckets.node_7.length, 1);
    assert.strictEqual(buckets.node_7[0].instanceId, 'dark_tower_spire_08');

    // Custom marked prop must route to custom_spawns bucket despite (-1150, -1150) coords
    assert.strictEqual(buckets[CUSTOM_SPAWNS_SECTOR_ID].length, 1);
    assert.strictEqual(buckets[CUSTOM_SPAWNS_SECTOR_ID][0].instanceId, 'custom_spawn_gothic_gate');
  });

  it('should filter props dynamically by partial string on instanceId or assetName', () => {
    // Empty search query
    assert.strictEqual(filterOutlinerProps(sampleProps, '').length, sampleProps.length);
    assert.strictEqual(filterOutlinerProps(sampleProps, '   ').length, sampleProps.length);

    // Filter by asset name substring (case-insensitive)
    const bunkerMatches = filterOutlinerProps(sampleProps, 'bunker');
    assert.strictEqual(bunkerMatches.length, 1);
    assert.strictEqual(bunkerMatches[0].instanceId, 'bunker_structure_01');

    // Filter by partial instance ID
    const pipeMatches = filterOutlinerProps(sampleProps, 'pipe');
    assert.strictEqual(pipeMatches.length, 1);
    assert.strictEqual(pipeMatches[0].instanceId, 'rust_gorge_pipe_05');

    // Filter matching multiple items (e.g. "0" matches the 8 numbered nodes 01-08)
    const zeroMatches = filterOutlinerProps(sampleProps, '0');
    assert.strictEqual(zeroMatches.length, 8);

    // Non-matching search query
    const noMatches = filterOutlinerProps(sampleProps, 'xenomorph_queen_99');
    assert.strictEqual(noMatches.length, 0);
  });

  it('should filter grouped sector buckets and omit empty sectors during active queries', () => {
    const buckets = bucketPropsBySector(sampleProps);

    const filtered = filterGroupedProps(buckets, 'gothic');
    const matchingSectors = Object.keys(filtered);
    assert.strictEqual(matchingSectors.length, 1);
    assert.strictEqual(matchingSectors[0], CUSTOM_SPAWNS_SECTOR_ID);
    assert.strictEqual(filtered[CUSTOM_SPAWNS_SECTOR_ID].length, 1);
  });

  it('should compute smooth focus camera position with elevation and distance offsets', () => {
    const propPos = { x: 120.0, y: 15.0, z: -40.0 };
    const focusPos = calculateFocusCameraPosition(propPos, 5.0, 12.0);

    assert.strictEqual(focusPos.x, 120.0);
    assert.strictEqual(focusPos.y, 20.0);
    assert.strictEqual(focusPos.z, -28.0);
  });

  it('should manage outliner selection state without throwing on null or invalid inputs', () => {
    const state = new EditorOutlinerState();
    state.registerProps(sampleProps);

    assert.strictEqual(state.getAllProps().length, sampleProps.length);
    assert.strictEqual(state.getSelectedIds().length, 0);
    assert.strictEqual(state.getPrimarySelectedProp(), null);

    // Select valid prop
    const sel = state.selectProp('rust_gorge_pipe_05');
    assert.ok(sel);
    assert.strictEqual(sel.instanceId, 'rust_gorge_pipe_05');
    assert.strictEqual(state.isPropSelected('rust_gorge_pipe_05'), true);
    assert.strictEqual(state.getSelectedIds().length, 1);

    // Multi-selection toggle
    state.selectProp('cradle_ruin_arch_04', true);
    assert.strictEqual(state.getSelectedIds().length, 2);
    assert.strictEqual(state.isPropSelected('cradle_ruin_arch_04'), true);

    // Toggle cradle_ruin_arch_04 off
    state.selectProp('cradle_ruin_arch_04', true);
    assert.strictEqual(state.getSelectedIds().length, 1);
    assert.strictEqual(state.isPropSelected('cradle_ruin_arch_04'), false);

    // Select null clears selection
    state.selectProp(null);
    assert.strictEqual(state.getSelectedIds().length, 0);
    assert.strictEqual(state.getPrimarySelectedProp(), null);

    // Non-existent ID does not throw and handles gracefully
    const invalidSel = state.selectProp('ghost_prop_does_not_exist');
    assert.strictEqual(invalidSel, null);
    assert.strictEqual(state.getSelectedIds().length, 0);
  });

  it('should track modified unsaved state, deletions, and real-time updates', () => {
    const state = new EditorOutlinerState();
    state.registerProps(sampleProps);

    assert.strictEqual(state.getUnsavedCount(), 0);

    // Mark single prop as modified
    state.markModified('bunker_structure_01');
    assert.strictEqual(state.isModified('bunker_structure_01'), true);
    assert.strictEqual(state.getUnsavedCount(), 1);

    // Mark second prop
    state.markModified('rust_gorge_pipe_05');
    assert.strictEqual(state.getUnsavedCount(), 2);

    // Clear one
    state.clearModified('bunker_structure_01');
    assert.strictEqual(state.isModified('bunker_structure_01'), false);
    assert.strictEqual(state.getUnsavedCount(), 1);

    // Clear all (e.g. after save to json)
    state.clearModified();
    assert.strictEqual(state.getUnsavedCount(), 0);

    // Prop deletion unregisters and cleans up selection
    state.selectProp('salt_flat_pole_03');
    assert.strictEqual(state.isPropSelected('salt_flat_pole_03'), true);
    state.unregisterProp('salt_flat_pole_03');
    assert.strictEqual(state.getProp('salt_flat_pole_03'), null);
    assert.strictEqual(state.isPropSelected('salt_flat_pole_03'), false);
    assert.strictEqual(state.getAllProps().length, sampleProps.length - 1);
  });

  it('should support panel toggle and search query updates', () => {
    const state = new EditorOutlinerState();
    assert.strictEqual(state.isPanelOpen(), false);

    assert.strictEqual(state.togglePanel(), true);
    assert.strictEqual(state.isPanelOpen(), true);

    state.setPanelOpen(false);
    assert.strictEqual(state.isPanelOpen(), false);

    state.setSearchQuery('bunker');
    assert.strictEqual(state.getSearchQuery(), 'bunker');
    state.registerProps(sampleProps);

    const bucketed = state.getBucketedProps();
    assert.strictEqual(bucketed.node_0.length, 1);
    assert.strictEqual(bucketed.node_1.length, 0);
  });
});
