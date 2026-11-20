/**
 * Regional Traversal & Connection Graph Unit Tests
 * The Path of Ka - Master Regional Topology
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  REGIONAL_NODES,
  REGIONAL_CORRIDORS,
  getRegionalNode,
  getAllRegionalNodes,
  getRegionalCorridor,
  getCorridorBetween,
  getCorridorsForNode,
  getNavigableCorridors,
  canTraverseDirectly,
  findNavigablePath,
} from '../world/worldGraph.ts';

describe('Node-Based Regional Traversal & Connection Graph', () => {
  it('should validate all 8 regional nodes and their master topology', () => {
    const nodes = getAllRegionalNodes();
    assert.equal(nodes.length, 8, 'Master graph must contain exactly 8 regional nodes');

    // Node 0: Mohaine Way-Bunker Sanctuary
    const node0 = getRegionalNode('waystation_sanctuary')!;
    assert.ok(node0);
    assert.equal(node0.nodeIndex, 0);
    assert.equal(node0.isSafeZone, true);
    assert.equal(node0.center.x, -1000.0);
    assert.equal(node0.center.z, -800.0);
    assert.ok(node0.connectedNodeIds.includes('sw_desolation'), 'Node 0 connects to Node 1');
    assert.ok(node0.connectedNodeIds.includes('south_salt'), 'Node 0 connects to Node 2 via culvert');

    // Node 1: Southwest Desolation
    const node1 = getRegionalNode('sw_desolation')!;
    assert.equal(node1.nodeIndex, 1);
    assert.equal(node1.isSafeZone, false);
    assert.ok(node1.connectedNodeIds.includes('waystation_sanctuary'));
    assert.ok(node1.connectedNodeIds.includes('south_salt'));

    // Node 2: Dead-Creek Salt Flats
    const node2 = getRegionalNode('south_salt')!;
    assert.equal(node2.nodeIndex, 2);
    assert.ok(node2.connectedNodeIds.includes('waystation_sanctuary'));
    assert.ok(node2.connectedNodeIds.includes('sw_desolation'));
    assert.ok(node2.connectedNodeIds.includes('cradle'));

    // Node 3: Caliche Cradle Hub
    const node3 = getRegionalNode('cradle')!;
    assert.equal(node3.nodeIndex, 3);
    assert.ok(node3.connectedNodeIds.includes('south_salt'));
    assert.ok(node3.connectedNodeIds.includes('west_gorge'));
    assert.ok(node3.connectedNodeIds.includes('north_alkali'));
    assert.ok(node3.connectedNodeIds.includes('east_dunes'));
    assert.ok(node3.connectedNodeIds.includes('monolith_pass'));

    // Node 4: Rust-Gorge Defile
    const node4 = getRegionalNode('west_gorge')!;
    assert.equal(node4.nodeIndex, 4);
    assert.ok(node4.connectedNodeIds.includes('cradle'));
    assert.ok(node4.connectedNodeIds.includes('north_alkali'));

    // Node 5: Bleached Alkali Sink
    const node5 = getRegionalNode('north_alkali')!;
    assert.equal(node5.nodeIndex, 5);
    assert.ok(node5.connectedNodeIds.includes('cradle'));
    assert.ok(node5.connectedNodeIds.includes('west_gorge'));
    assert.ok(node5.connectedNodeIds.includes('monolith_pass'));

    // Node 6: The Great Shifting Erg
    const node6 = getRegionalNode('east_dunes')!;
    assert.equal(node6.nodeIndex, 6);
    assert.ok(node6.connectedNodeIds.includes('cradle'));
    assert.ok(node6.connectedNodeIds.includes('monolith_pass'));

    // Node 7: Threshold of the Dark Tower
    const node7 = getRegionalNode('monolith_pass')!;
    assert.equal(node7.nodeIndex, 7);
    assert.ok(node7.connectedNodeIds.includes('north_alkali'));
    assert.ok(node7.connectedNodeIds.includes('east_dunes'));
    assert.ok(node7.connectedNodeIds.includes('cradle'));
  });

  it('should validate all corridors, choke points, and hazard multipliers', () => {
    assert.equal(REGIONAL_CORRIDORS.length, 11, 'Must register 11 pathway corridors and connectors');

    // 1. Sanctuary Gate Choke Point
    const gateCorridor = getRegionalCorridor('pass_sanctuary_to_sw')!;
    assert.ok(gateCorridor);
    assert.equal(gateCorridor.corridorType, 'CHOKE_POINT');
    assert.deepEqual(gateCorridor.chokePoint, { x: -900.0, y: 0.0, z: -820.0 });
    assert.equal(gateCorridor.hazardMultiplier, 1.0);
    assert.equal(gateCorridor.isBlocked, false);

    // 2. Sanctuary to Salt Culvert
    const culvertCorridor = getRegionalCorridor('pass_sanctuary_to_salt')!;
    assert.ok(culvertCorridor);
    assert.equal(culvertCorridor.corridorType, 'ANCIENT_TUNNEL');
    assert.equal(culvertCorridor.hazardType, 'SALT_CORROSION');
    assert.equal(culvertCorridor.hazardMultiplier, 1.4);
    assert.equal(culvertCorridor.isBlocked, false);

    // 3. West Caliche Defile Choke Point
    const gorgePass = getRegionalCorridor('pass_cradle_to_gorge')!;
    assert.ok(gorgePass);
    assert.equal(gorgePass.hazardType, 'IRON_OXIDE');
    assert.equal(gorgePass.hazardMultiplier, 1.8);

    // 4. Hazardous Blocked Thinny Abyss Connector
    const thinnyConnector = getRegionalCorridor('connector_cradle_to_monolith_thinny')!;
    assert.ok(thinnyConnector);
    assert.equal(thinnyConnector.corridorType, 'HAZARDOUS_ABYSS');
    assert.equal(thinnyConnector.isBlocked, true, 'Thinny Abyss connector must be blocked for direct traversal');
    assert.equal(thinnyConnector.hazardType, 'THINNY_DISTORTION');
    assert.equal(thinnyConnector.hazardMultiplier, 4.5, 'Thinny Abyss has highest hazard multiplier');
    assert.equal(thinnyConnector.staminaDrainMultiplier, 2.5);
    assert.deepEqual(thinnyConnector.chokePoint, { x: 325.0, y: -28.0, z: 325.0 });

    // 5. Verify all corridors have positive widths and valid endpoints
    for (const c of REGIONAL_CORRIDORS) {
      assert.ok(c.halfWidthMeters >= 12.0);
      assert.ok(c.staminaDrainMultiplier >= 1.0);
      assert.ok(c.hazardMultiplier >= 1.0);
      assert.notEqual(c.fromBasin, c.toBasin);
    }
  });

  it('should enforce pathway traversal restrictions and reject invalid direct leaps', () => {
    // Legal direct corridors
    assert.equal(canTraverseDirectly('waystation_sanctuary', 'sw_desolation'), true);
    assert.equal(canTraverseDirectly('waystation_sanctuary', 'south_salt'), true);
    assert.equal(canTraverseDirectly('south_salt', 'cradle'), true);
    assert.equal(canTraverseDirectly('cradle', 'west_gorge'), true);
    assert.equal(canTraverseDirectly('cradle', 'north_alkali'), true);
    assert.equal(canTraverseDirectly('cradle', 'east_dunes'), true);
    assert.equal(canTraverseDirectly('north_alkali', 'monolith_pass'), true);
    assert.equal(canTraverseDirectly('east_dunes', 'monolith_pass'), true);

    // Blocked route: Cradle directly to Monolith Pass along Beam (Thinny Abyss)
    assert.equal(canTraverseDirectly('cradle', 'monolith_pass'), false, 'Direct Beam crossing is blocked by Thinny Abyss');

    // Disconnected arbitrary grid jumps
    assert.equal(canTraverseDirectly('waystation_sanctuary', 'monolith_pass'), false, 'Cannot jump across map to Tower');
    assert.equal(canTraverseDirectly('waystation_sanctuary', 'north_alkali'), false, 'Cannot jump to North Alkali');
    assert.equal(canTraverseDirectly('sw_desolation', 'east_dunes'), false, 'Cannot jump across to East Dunes');
  });

  it('should compute valid multi-hop paths circumventing hazardous blocked routes', () => {
    // Navigable corridors must exclude the blocked Thinny Abyss
    const navigable = getNavigableCorridors();
    assert.equal(navigable.length, 10);
    assert.ok(!navigable.some(c => c.isBlocked));

    // Pathfinding from Node 0 (waystation_sanctuary) to Node 7 (monolith_pass)
    const path = findNavigablePath('waystation_sanctuary', 'monolith_pass');
    assert.ok(path, 'Must find a navigable path to the Dark Tower');
    assert.equal(path[0], 'waystation_sanctuary');
    assert.equal(path[path.length - 1], 'monolith_pass');

    // Verify every step in the path is a legal, unblocked connection
    for (let i = 0; i < path.length - 1; i++) {
      const stepA = path[i];
      const stepB = path[i + 1];
      assert.equal(canTraverseDirectly(stepA, stepB), true, `Step ${stepA} -> ${stepB} must be directly traversable`);
    }

    // Path from Cradle (Node 3) to Tower (Node 7) must detour around the Thinny Abyss
    const cradleToTower = findNavigablePath('cradle', 'monolith_pass');
    assert.ok(cradleToTower);
    assert.equal(cradleToTower[0], 'cradle');
    assert.equal(cradleToTower[cradleToTower.length - 1], 'monolith_pass');
    assert.ok(
      cradleToTower.includes('north_alkali') || cradleToTower.includes('east_dunes'),
      'Must detour via North Pass or East Dunes'
    );
  });
});

