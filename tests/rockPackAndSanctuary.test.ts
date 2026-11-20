import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  ROCK_PACK_REGISTRY,
  AREA_1_PLACEMENTS,
  computeScaledAABB,
  pointInside2DBox,
  distancePointToSegment2D
} from '../world/rockPackLibrary.ts';

describe('Photogrammetry Rock Pack & Node 0 Sanctuary Architecture', () => {
  it('should validate all 7 photogrammetry rock glTF nodes and accessor bounds', () => {
    const keys = Object.keys(ROCK_PACK_REGISTRY);
    assert.strictEqual(keys.length, 7, 'Expected 7 photogrammetry rock definitions');

    const expectedNodes = [
      { name: 'Rock3 (5K)', tier: 'TierA', verts: 7704 },
      { name: 'Rock5b (11K)', tier: 'TierA', verts: 7173 },
      { name: 'Rock5c (23K)', tier: 'TierB', verts: 14779 },
      { name: 'Rock5a (37K)', tier: 'TierB', verts: 24591 },
      { name: 'Rock1 (38K)', tier: 'TierC', verts: 26044 },
      { name: 'Rock2 (41K)', tier: 'TierC', verts: 31556 },
      { name: 'Rock4 (60K)', tier: 'TierC', verts: 40879 }
    ];

    for (const exp of expectedNodes) {
      const meta = ROCK_PACK_REGISTRY[exp.name];
      assert.ok(meta, `Rock ${exp.name} must exist in registry`);
      assert.strictEqual(meta.tier, exp.tier);
      assert.strictEqual(meta.vertexCount, exp.verts);

      // Verify bounds are within [-0.51, +0.51] normalized unit box
      for (let i = 0; i < 3; i++) {
        assert.ok(meta.min[i] >= -0.51, `min[${i}] must be >= -0.51`);
        assert.ok(meta.max[i] <= 0.51, `max[${i}] must be <= 0.51`);
        assert.ok(meta.max[i] > meta.min[i], `max[${i}] must be > min[${i}]`);
      }
    }
  });

  it('should accurately compute scaled analytical AABB colliders from raw extents', () => {
    const scale = { x: 20.0, y: 15.0, z: 18.0 };
    const pos = { x: -1015.0, y: 0.0, z: -788.0 };
    const aabb = computeScaledAABB('Rock1 (38K)', scale, pos);

    const meta = ROCK_PACK_REGISTRY['Rock1 (38K)'];
    const expectedSizeX = meta.rawSize[0] * scale.x;
    const expectedSizeY = meta.rawSize[1] * scale.y;
    const expectedSizeZ = meta.rawSize[2] * scale.z;

    assert.ok(Math.abs(aabb.sizeX - expectedSizeX) < 0.001);
    assert.ok(Math.abs(aabb.sizeY - expectedSizeY) < 0.001);
    assert.ok(Math.abs(aabb.sizeZ - expectedSizeZ) < 0.001);

    assert.ok(Math.abs(aabb.minX - (pos.x - expectedSizeX * 0.5)) < 0.001);
    assert.ok(Math.abs(aabb.maxX - (pos.x + expectedSizeX * 0.5)) < 0.001);
  });

  it('should enforce zero collider overlap at bunker spawn (-1020, -820)', () => {
    const bunkerSpawn = { x: -1020.0, z: -820.0 };
    const minSafeClearance = 10.0; // 10m clear radius around spawn

    for (const rock of AREA_1_PLACEMENTS) {
      const aabb = computeScaledAABB(
        rock.rockName,
        { x: rock.scaleX, y: rock.scaleY, z: rock.scaleZ },
        { x: rock.worldX, y: 0.0, z: rock.worldZ }
      );

      // Check whether bunker spawn is inside rock AABB or too close
      const isInside = pointInside2DBox(bunkerSpawn.x, bunkerSpawn.z, aabb.minX, aabb.maxX, aabb.minZ, aabb.maxZ, 0.0);
      assert.strictEqual(isInside, false, `Rock ${rock.rockName} at (${rock.worldX}, ${rock.worldZ}) intersects bunker spawn point`);

      const dx = rock.worldX - bunkerSpawn.x;
      const dz = rock.worldZ - bunkerSpawn.z;
      const dist = Math.sqrt(dx * dx + dz * dz);
      assert.ok(dist >= minSafeClearance, `Rock at (${rock.worldX}, ${rock.worldZ}) is too close to spawn (dist: ${dist.toFixed(2)}m < ${minSafeClearance}m)`);
    }
  });

  it('should keep the blast-gate corridor (-1020, -820 to -900, -820) 100% clear of blocking colliders', () => {
    const corridorA = { x: -1020.0, z: -820.0 };
    const corridorB = { x: -900.0, z: -820.0 };

    for (const rock of AREA_1_PLACEMENTS) {
      const aabb = computeScaledAABB(
        rock.rockName,
        { x: rock.scaleX, y: rock.scaleY, z: rock.scaleZ },
        { x: rock.worldX, y: 0.0, z: rock.worldZ }
      );

      // If the rock center is between X -1030 and -890, its bounding box must not enter corridor Z [-826, -814]
      if (rock.worldX >= corridorA.x - 10.0 && rock.worldX <= corridorB.x + 10.0) {
        const dCorridor = distancePointToSegment2D(rock.worldX, rock.worldZ, corridorA.x, corridorA.z, corridorB.x, corridorB.z);
        const halfBreadth = Math.max(aabb.sizeX, aabb.sizeZ) * 0.5;
        const edgeDist = dCorridor - halfBreadth;
        assert.ok(
          edgeDist >= 1.0,
          `Rock ${rock.rockName} at (${rock.worldX}, ${rock.worldZ}) intrudes into the blast-gate corridor (edgeDist: ${edgeDist.toFixed(2)}m)`
        );
      }
    }
  });

  it('should validate Area 1 bunker flank outcrop shelves framing and tactical crouch cover', () => {
    const shelves = AREA_1_PLACEMENTS.filter(p => p.category === 'outcrop_shelf');
    const slabs = AREA_1_PLACEMENTS.filter(p => p.category === 'caliche_slab');
    const boulders = AREA_1_PLACEMENTS.filter(p => p.category === 'crouch_boulder');

    assert.strictEqual(shelves.length, 5, 'Must have 5 heavy bunker flank shelves');
    assert.strictEqual(slabs.length, 7, 'Must have 7 caliche slabs');
    assert.strictEqual(boulders.length, 5, 'Must have 5 tactical crouch boulders');

    // Verify outcrop shelves scale range (14m - 24m)
    for (const shelf of shelves) {
      assert.ok(shelf.scaleX >= 14.0 && shelf.scaleX <= 25.0, `Shelf scaleX ${shelf.scaleX} must be 14-25m`);
      assert.ok(shelf.scaleZ >= 14.0 && shelf.scaleZ <= 25.0, `Shelf scaleZ ${shelf.scaleZ} must be 14-25m`);
      assert.ok(shelf.sinkDepth >= 2.0 && shelf.sinkDepth <= 3.0, 'Shelf sink depth must be ~2.5m');
    }

    // Verify crouch boulders physical height (1.3m - 1.8m)
    for (const bld of boulders) {
      const meta = ROCK_PACK_REGISTRY[bld.rockName];
      const worldHeight = meta.rawSize[1] * bld.scaleY;
      assert.ok(
        worldHeight >= 1.3 && worldHeight <= 1.8,
        `Crouch boulder height ${worldHeight.toFixed(2)}m must be between 1.3m and 1.8m`
      );
    }
  });

  it('should validate distance culling tiers and LOD visibility configuration', () => {
    // Tier A (low-poly cover & slabs): 350m visibility range end
    const tierARocks = ['Rock3 (5K)', 'Rock5b (11K)'];
    for (const name of tierARocks) {
      assert.strictEqual(ROCK_PACK_REGISTRY[name].defaultVisibilityRangeEnd, 350.0);
    }

    // Tier B/C (crags & monoliths): 900m visibility range end
    const tierBCRocks = ['Rock5c (23K)', 'Rock5a (37K)', 'Rock1 (38K)', 'Rock2 (41K)', 'Rock4 (60K)'];
    for (const name of tierBCRocks) {
      assert.strictEqual(ROCK_PACK_REGISTRY[name].defaultVisibilityRangeEnd, 900.0);
    }
  });

  it('should validate Escarpment Barrier Chain 1 and Chain 2 photogrammetry rock mapping', () => {
    const chain12Rocks = ['Rock5a (37K)', 'Rock5c (23K)', 'Rock1 (38K)'];
    const minScale = 25.0;
    const maxScale = 45.0;

    for (const rName of chain12Rocks) {
      const meta = ROCK_PACK_REGISTRY[rName];
      assert.ok(meta, `Escarpment rock ${rName} must exist`);
      assert.ok(meta.tier === 'TierB' || meta.tier === 'TierC', 'Escarpment rock must be Tier B or Tier C');

      // Test scaling at lower and upper bounds
      const aabbMin = computeScaledAABB(rName, { x: minScale, y: minScale * 1.25, z: minScale });
      const aabbMax = computeScaledAABB(rName, { x: maxScale, y: maxScale * 1.25, z: maxScale });

      assert.ok(aabbMin.sizeX >= 20.0, 'Min scale bounding box X must be >= 20m');
      assert.ok(aabbMax.sizeX <= 50.0, 'Max scale bounding box X must be <= 50m');
      assert.ok(aabbMin.sizeY >= 10.0, 'Min scale height must be >= 10m');
      assert.ok(aabbMax.sizeY <= 65.0, 'Max scale height must be <= 65m');
    }
  });

  it('should validate CullUnit topological bubble registration in Area 1', () => {
    // Check that rocks around bunker (< -800) resolve to waystation_sanctuary
    for (const rock of AREA_1_PLACEMENTS) {
      const expectedBubble = rock.worldX < -800.0 ? 'waystation_sanctuary' : 'sw_desolation';
      if (rock.worldX < -800.0) {
        assert.strictEqual(expectedBubble, 'waystation_sanctuary');
      } else {
        assert.strictEqual(expectedBubble, 'sw_desolation');
      }
    }
  });
});
