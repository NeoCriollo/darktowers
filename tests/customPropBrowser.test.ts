/**
 * Unit Tests for Custom .glb Folder Scanner & Dynamic Previewer (Phase 5)
 * Validates directory filtering, filename formatting, material inference,
 * AABB scaling normalization, pivot recentering, and custom asset overrides.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  isValid3dFile,
  formatDisplayName,
  inferMaterialFromName,
  parseCustomPropsDirectory,
  computeAABBNormalization,
  TARGET_NORMALIZED_DIMENSION,
  COLLISION_LAYER_WORLD,
  simulateMeshCollisionPass,
  simulateDisableAllCollisions,
  type MockHierarchyNode
} from '../world/customPropBrowser.ts';
import {
  validateLayoutSchema,
  validateNode0SanctuaryClearance,
  NODE_0_BUNKER_SPAWN,
  type WorldLayoutOverrideData
} from '../world/worldLayoutPersistence.ts';

describe('Custom .glb Folder Scanner & Dynamic Previewer (Phase 5)', () => {
  it('should filter valid .glb and .gltf files and ignore .import, textures, and dotfiles', () => {
    assert.strictEqual(isValid3dFile('ancient_column.glb'), true);
    assert.strictEqual(isValid3dFile('broken_wagon.GLTF'), true);
    assert.strictEqual(isValid3dFile('ancient_column.glb.import'), false);
    assert.strictEqual(isValid3dFile('texture_albedo.png'), false);
    assert.strictEqual(isValid3dFile('roughness.jpg'), false);
    assert.strictEqual(isValid3dFile('.gitkeep'), false);
  });

  it('should format display names and clean exporter stems cleanly', () => {
    assert.strictEqual(formatDisplayName('ancient_waystation_pylon'), 'Ancient Waystation Pylon');
    assert.strictEqual(formatDisplayName('medieval_wall_of_bricks_assets'), 'Medieval Wall Of Bricks');
    assert.strictEqual(formatDisplayName('iron-girder-collapsed'), 'Iron Girder Collapsed');
    assert.strictEqual(formatDisplayName('074d356a225ad34654973c865953d42a'), 'Model #074D356A');
    assert.strictEqual(formatDisplayName('cactus__pack'), 'Cactus Pack');
  });

  it('should accurately infer ballistic material types based on name stems', () => {
    assert.strictEqual(inferMaterialFromName('steel_truss_overpass'), 'STEEL');
    assert.strictEqual(inferMaterialFromName('bunker_blast_frame'), 'STEEL');
    assert.strictEqual(inferMaterialFromName('weathered_wood_plank'), 'WOOD');
    assert.strictEqual(inferMaterialFromName('ancient_skull_pile'), 'BONE');
    assert.strictEqual(inferMaterialFromName('thinny_plasma_rift'), 'ENERGY');
    assert.strictEqual(inferMaterialFromName('desert_sandstone_slab'), 'STONE');
  });

  it('should parse custom props directory and sort deterministically', () => {
    const mockFiles = [
      'sandstone_arch.glb',
      'texture_0.png',
      '.hidden_file',
      'iron_girder.glb',
      'sandstone_arch.glb.import',
      'wooden_crate.gltf'
    ];

    const entries = parseCustomPropsDirectory(mockFiles);
    assert.strictEqual(entries.length, 3);
    assert.strictEqual(entries[0].name, 'Iron Girder');
    assert.strictEqual(entries[0].material, 'STEEL');
    assert.strictEqual(entries[0].id, 'custom_iron_girder');
    assert.strictEqual(entries[1].name, 'Sandstone Arch');
    assert.strictEqual(entries[1].material, 'STONE');
    assert.strictEqual(entries[2].name, 'Wooden Crate');
    assert.strictEqual(entries[2].material, 'WOOD');
  });

  it('should normalize oversized models (>50m) down to sensible ~2.5m human scale', () => {
    // 120m gigantic model
    const minBound: [number, number, number] = [-60.0, 0.0, -60.0];
    const maxBound: [number, number, number] = [60.0, 120.0, 60.0];

    const norm = computeAABBNormalization(minBound, maxBound);
    assert.strictEqual(norm.maxDimension, 120.0);
    assert.ok(norm.scaleFactor < 0.05);

    const maxNormalized = Math.max(
      norm.normalizedSize.x,
      Math.max(norm.normalizedSize.y, norm.normalizedSize.z)
    );
    assert.ok(Math.abs(maxNormalized - TARGET_NORMALIZED_DIMENSION) < 0.001);
  });

  it('should normalize microscopic models (<0.15m) up to ~2.5m human scale', () => {
    // 0.02m millimeter-scale model
    const minBound: [number, number, number] = [-0.01, 0.0, -0.01];
    const maxBound: [number, number, number] = [0.01, 0.02, 0.01];

    const norm = computeAABBNormalization(minBound, maxBound);
    assert.strictEqual(norm.maxDimension, 0.02);
    assert.ok(norm.scaleFactor > 100.0);

    const maxNormalized = Math.max(
      norm.normalizedSize.x,
      Math.max(norm.normalizedSize.y, norm.normalizedSize.z)
    );
    assert.ok(Math.abs(maxNormalized - TARGET_NORMALIZED_DIMENSION) < 0.001);
  });

  it('should retain unscaled 1.0x factor for human-scale assets', () => {
    // 3.5m regular boulder
    const minBound: [number, number, number] = [-1.5, 0.0, -1.0];
    const maxBound: [number, number, number] = [1.5, 3.5, 1.0];

    const norm = computeAABBNormalization(minBound, maxBound);
    assert.strictEqual(norm.scaleFactor, 1.0);
    assert.strictEqual(norm.normalizedSize.y, 3.5);
  });

  it('should compute bottom-center pivot offsets for off-center meshes', () => {
    // Model whose origin is offset by (+15, +5, -20)
    const minBound: [number, number, number] = [10.0, 5.0, -25.0];
    const maxBound: [number, number, number] = [20.0, 15.0, -15.0];

    const norm = computeAABBNormalization(minBound, maxBound);
    // Center X should be 15.0 -> offset -15.0
    assert.strictEqual(norm.pivotOffset.x, -15.0);
    // Bottom Y is 5.0 -> offset -5.0
    assert.strictEqual(norm.pivotOffset.y, -5.0);
    // Center Z should be -20.0 -> offset +20.0
    assert.strictEqual(norm.pivotOffset.z, 20.0);
  });

  it('should support custom props with asset_path in layout overrides and enforce Node 0 sanctuary clearance', () => {
    const layoutWithCustomProp: WorldLayoutOverrideData = {
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      modifications: {},
      deletions: [],
      spawned: [
        {
          instance_id: 'custom_iron_girder_001',
          asset_id: 'custom_iron_girder',
          position: [-850.0, 2.0, -750.0],
          rotation: [0.0, 30.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        }
      ]
    };

    // Verify safe location passes
    const clearance = validateNode0SanctuaryClearance(layoutWithCustomProp);
    assert.strictEqual(clearance.clear, true);
    assert.strictEqual(clearance.violations.length, 0);

    // Verify placement in bunker corridor is rejected
    const badCorridorLayout: WorldLayoutOverrideData = {
      ...layoutWithCustomProp,
      spawned: [
        {
          instance_id: 'bad_custom_prop',
          asset_id: 'custom_iron_girder',
          position: [-1120.0, 0.0, -1120.0], // inside corridor from bunker to gate
          rotation: [0.0, 0.0, 0.0],
          scale: [1.0, 1.0, 1.0]
        }
      ]
    };

    const badClearance = validateNode0SanctuaryClearance(badCorridorLayout);
    assert.strictEqual(badClearance.clear, false);
    assert.ok(badClearance.violations.some((v) => v.includes('blast-gate corridor')));
  });

  it('should automatically generate convex collisions on instantiated .glb scenes lacking colliders', () => {
    // Model with nested meshes lacking collision
    const mockGlbScene: MockHierarchyNode = {
      name: 'CustomProp_SandstoneArch',
      type: 'Node3D',
      children: [
        {
          name: 'ModelPivot',
          type: 'Node3D',
          children: [
            {
              name: 'ArchPillarLeft',
              type: 'MeshInstance3D',
              hasMesh: true,
              children: [],
              meta: {}
            },
            {
              name: 'ArchPillarRight',
              type: 'MeshInstance3D',
              hasMesh: true,
              children: [],
              meta: {}
            },
            {
              name: 'ArchKeystone',
              type: 'MeshInstance3D',
              hasMesh: true,
              children: [],
              meta: {}
            }
          ],
          meta: {}
        }
      ],
      meta: {}
    };

    const report = simulateMeshCollisionPass(mockGlbScene, {
      collisionLayer: COLLISION_LAYER_WORLD,
      ballisticMaterial: 'STONE'
    });

    assert.strictEqual(report.checkedMeshes, 3);
    assert.strictEqual(report.generatedCollisions, 3);
    assert.strictEqual(report.existingCollisions, 0);

    // Verify pillar left has generated StaticBody3D on layer 1
    const modelPivot = mockGlbScene.children[0];
    const leftPillar = modelPivot.children[0];
    assert.strictEqual(leftPillar.children.length, 1);
    const colBody = leftPillar.children[0];
    assert.strictEqual(colBody.type, 'StaticBody3D');
    assert.strictEqual(colBody.collisionLayer, 1);
    assert.strictEqual(colBody.collisionMask, 0);
    assert.strictEqual(colBody.meta.ballistic_material, 'STONE');
    assert.strictEqual(colBody.meta.reactive_target, true);

    // Verify child CollisionShape3D exists
    assert.strictEqual(colBody.children.length, 1);
    assert.strictEqual(colBody.children[0].type, 'CollisionShape3D');
  });

  it('should not duplicate collision if mesh already has collision attached', () => {
    const mockModelWithCollision: MockHierarchyNode = {
      name: 'CustomProp_BunkerHatch',
      type: 'Node3D',
      children: [
        {
          name: 'HatchMesh',
          type: 'MeshInstance3D',
          hasMesh: true,
          children: [
            {
              name: 'ExistingCol',
              type: 'StaticBody3D',
              collisionLayer: 1,
              collisionMask: 0,
              children: [],
              meta: {}
            }
          ],
          meta: {}
        }
      ],
      meta: {}
    };

    const report = simulateMeshCollisionPass(mockModelWithCollision, {
      collisionLayer: COLLISION_LAYER_WORLD,
      ballisticMaterial: 'STEEL'
    });

    assert.strictEqual(report.checkedMeshes, 1);
    assert.strictEqual(report.generatedCollisions, 0);
    assert.strictEqual(report.existingCollisions, 1);
    // Preserved only the original collision body
    assert.strictEqual(mockModelWithCollision.children[0].children.length, 1);
  });

  it('should disable all collision layers when building holo-ghost previews', () => {
    const mockGhostModel: MockHierarchyNode = {
      name: 'HoloGhost_CustomProp_IronGirder',
      type: 'Node3D',
      collisionLayer: 1,
      children: [
        {
          name: 'GirderMesh',
          type: 'MeshInstance3D',
          hasMesh: true,
          children: [
            {
              name: 'Girder_col',
              type: 'StaticBody3D',
              collisionLayer: 1,
              collisionMask: 0,
              children: [],
              meta: {}
            }
          ],
          meta: {}
        }
      ],
      meta: {}
    };

    simulateDisableAllCollisions(mockGhostModel);

    assert.strictEqual(mockGhostModel.collisionLayer, 0);
    const colBody = mockGhostModel.children[0].children[0];
    assert.strictEqual(colBody.collisionLayer, 0);
    assert.strictEqual(colBody.collisionMask, 0);
  });
});

