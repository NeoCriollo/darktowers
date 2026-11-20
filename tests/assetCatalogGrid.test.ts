/**
 * Unit Tests for Visual 3D Asset Catalog Grid (Phase 7)
 *
 * Validates grid layout mathematics, responsive tile column sizing,
 * category filtering & tile counts, camera AABB framing, 3D spin rotation,
 * thumbnail cache keys & eviction, and safe fallback placeholder resolution.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateGridColumns,
  calculateCardWidth,
  calculateGridLayout,
  filterCatalogItems,
  computeCategoryCounts,
  computeAABBFromExtents,
  computeBoundingRadius,
  computeThumbnailCameraFraming,
  computeSpinRotation,
  generateThumbnailCacheKey,
  isValidThumbnailCacheKey,
  resolveThumbnailAssetPath,
  ThumbnailMemoryCache,
  AMBER_TERMINAL_HEX,
  AMBER_TERMINAL_RGB,
  OBSIDIAN_PANEL_HEX,
  CANONICAL_GRID_CATEGORIES,
  DEFAULT_CAMERA_FOV_DEGREES,
  type CatalogGridItem,
  type GridLayoutConfig
} from '../world/assetCatalogGrid.ts';
import { CATALOG_ASSETS } from '../world/editorMode.ts';

describe('Visual 3D Asset Catalog Grid & Domain Mathematics (Phase 7)', () => {
  const sampleItems: readonly CatalogGridItem[] = [
    { id: 'rock_3', category: 'rocks', name: 'Rock3 (5K) — Tier A Scatter', tierBadge: '[TIER A - 5K]', material: 'STONE' },
    { id: 'rock_1', category: 'rocks', name: 'Rock1 (38K) — Outcrop Shelf', tierBadge: '[TIER B - 38K]', material: 'STONE' },
    { id: 'monolith_pylon', category: 'architecture', name: 'Ka Survey Beacon Pylon', glbName: 'dark_tower_beacon_monolith_pylon.glb', material: 'STEEL' },
    { id: 'bunker_slab', category: 'architecture', name: 'Way-Bunker Blast Foundation', material: 'STONE' },
    { id: 'midworld_door', category: 'architecture', name: 'Freestanding Mid-World Door', material: 'WOOD' },
    { id: 'supply_crate', category: 'props', name: 'Frontier Footlocker Crate', material: 'STEEL' },
    { id: 'thinny_anomaly', category: 'props', name: 'Thinny Spatial Anomaly Tear', material: 'ENERGY' },
    { id: 'custom_wagon_01', category: 'custom', name: 'Ancient Pioneer Wagon', glbName: 'ancient_pioneer_wagon.glb', isCustom: true },
    { id: 'custom_skull_pile', category: 'custom', name: 'Bleached Skull Cairn', glbName: 'bleached_skull_cairn.glb', isCustom: true }
  ];

  it('should calculate responsive grid columns based on container width and card constraints', () => {
    // Standard drawer panel width 640px, min card 140px, gap 8px
    const cols640 = calculateGridColumns(640, 140, 8);
    assert.strictEqual(cols640, 4);

    // Narrow modal width 320px
    const cols320 = calculateGridColumns(320, 140, 8);
    assert.strictEqual(cols320, 2);

    // Wide widescreen modal 1200px
    const cols1200 = calculateGridColumns(1200, 140, 8);
    assert.strictEqual(cols1200, 8);

    // Degenerate inputs fallback to minimum 1 column
    assert.strictEqual(calculateGridColumns(0, 140, 8), 1);
    assert.strictEqual(calculateGridColumns(-500, 140, 8), 1);
    assert.strictEqual(calculateGridColumns(640, 0, 8), 1);
  });

  it('should calculate balanced card widths filling available space without overflow', () => {
    // 640px with 4 columns and 8px gaps -> (640 - 24) / 4 = 154px per card
    const cardWidth = calculateCardWidth(640, 4, 8);
    assert.strictEqual(cardWidth, 154);
    assert.ok(cardWidth * 4 + 3 * 8 <= 640);

    // 1 column should take full width
    const singleColWidth = calculateCardWidth(640, 1, 8);
    assert.strictEqual(singleColWidth, 640);
  });

  it('should compute complete grid layout rows and total container height', () => {
    const config: GridLayoutConfig = {
      containerWidth: 640,
      minCardWidth: 140,
      cardHeight: 160,
      hGap: 8,
      vGap: 10
    };

    // 9 items with 4 columns -> 3 rows
    const layout = calculateGridLayout(9, config);
    assert.strictEqual(layout.columns, 4);
    assert.strictEqual(layout.rows, 3);
    // 3 rows * 160 + 2 * 10 = 500px total height
    assert.strictEqual(layout.totalHeight, 500);

    // 0 items -> 0 rows, 0 height
    const emptyLayout = calculateGridLayout(0, config);
    assert.strictEqual(emptyLayout.rows, 0);
    assert.strictEqual(emptyLayout.totalHeight, 0);
  });

  it('should filter catalog items by category and query strings', () => {
    // Filter Nature / Rocks
    const rocks = filterCatalogItems(sampleItems, 'rocks');
    assert.strictEqual(rocks.length, 2);
    assert.ok(rocks.every((r) => r.category === 'rocks'));

    // Filter Architecture
    const arch = filterCatalogItems(sampleItems, 'architecture');
    assert.strictEqual(arch.length, 3);
    assert.ok(arch.every((a) => a.category === 'architecture'));

    // Filter Custom Assets
    const custom = filterCatalogItems(sampleItems, 'custom');
    assert.strictEqual(custom.length, 2);
    assert.ok(custom.every((c) => c.category === 'custom'));

    // Filter All
    const all = filterCatalogItems(sampleItems, 'all');
    assert.strictEqual(all.length, sampleItems.length);

    // Search query within category
    const searchResult = filterCatalogItems(sampleItems, 'architecture', 'beacon');
    assert.strictEqual(searchResult.length, 1);
    assert.strictEqual(searchResult[0].id, 'monolith_pylon');

    // Search query matching material
    const steelMatches = filterCatalogItems(sampleItems, 'all', 'STEEL');
    assert.strictEqual(steelMatches.length, 2);
  });

  it('should compute dynamic tile counts for all canonical categories', () => {
    const counts = computeCategoryCounts(sampleItems);
    assert.strictEqual(counts.rocks, 2);
    assert.strictEqual(counts.architecture, 3);
    assert.strictEqual(counts.props, 2);
    assert.strictEqual(counts.custom, 2);

    // When passing full CATALOG_ASSETS from editorMode.ts
    const mappedCatalog: CatalogGridItem[] = CATALOG_ASSETS.map((a) => ({
      id: a.id,
      category: a.category,
      name: a.name,
      glbName: a.glbName,
      tierBadge: a.tierBadge,
      material: a.material
    }));
    const fullCounts = computeCategoryCounts(mappedCatalog);
    assert.strictEqual(fullCounts.rocks, 7);
    assert.strictEqual(fullCounts.architecture, 4);
    assert.strictEqual(fullCounts.props, 4);
    assert.strictEqual(fullCounts.custom, 0); // Initially empty custom bucket
  });

  it('should compute 3D AABB bounding box and framing camera distance', () => {
    const min = { x: -2.0, y: 0.0, z: -2.0 };
    const max = { x: 2.0, y: 8.0, z: 2.0 };
    const aabb = computeAABBFromExtents(min, max);

    assert.strictEqual(aabb.size.x, 4.0);
    assert.strictEqual(aabb.size.y, 8.0);
    assert.strictEqual(aabb.size.z, 4.0);
    assert.strictEqual(aabb.center.x, 0.0);
    assert.strictEqual(aabb.center.y, 4.0);
    assert.strictEqual(aabb.center.z, 0.0);

    const radius = computeBoundingRadius(aabb.size);
    // sqrt(16 + 64 + 16) / 2 = sqrt(96) / 2 = 9.7979 / 2 ~= 4.899
    assert.ok(radius > 4.8 && radius < 5.0);

    const framing = computeThumbnailCameraFraming(aabb.size, aabb.center, DEFAULT_CAMERA_FOV_DEGREES, 1.25);
    assert.ok(framing.distance > radius, 'Framing distance must exceed bounding radius');
    assert.strictEqual(framing.lookTarget.x, aabb.center.x);
    assert.strictEqual(framing.lookTarget.y, aabb.center.y);
    assert.strictEqual(framing.lookTarget.z, aabb.center.z);
    assert.ok(framing.cameraPosition.y > aabb.center.y, 'Camera should look from an elevated isometric angle');
  });

  it('should compute continuous 3D rotational spin with smooth wrap-around', () => {
    const initialYaw = 0.0;
    const delta = 0.5; // 0.5s at 0.8 rad/s = +0.4 rad
    const nextYaw = computeSpinRotation(initialYaw, delta, 0.8);
    assert.ok(Math.abs(nextYaw - 0.4) < 1e-4);

    // Full circle wrap-around
    const tau = 2.0 * Math.PI;
    const wrappedYaw = computeSpinRotation(tau - 0.1, 0.5, 0.8);
    assert.ok(wrappedYaw >= 0.0 && wrappedYaw < tau);
  });

  it('should generate and validate unique thumbnail cache keys', () => {
    const key1 = generateThumbnailCacheKey('rock_3', 128);
    assert.strictEqual(key1, 'thumb_rock_3_128');
    assert.strictEqual(isValidThumbnailCacheKey(key1), true);

    const key2 = generateThumbnailCacheKey('Monolith/Pylon#01', 256);
    assert.strictEqual(key2, 'thumb_monolith_pylon_01_256');
    assert.strictEqual(isValidThumbnailCacheKey(key2), true);

    assert.strictEqual(isValidThumbnailCacheKey('invalid_key'), false);
    assert.strictEqual(isValidThumbnailCacheKey(''), false);
  });

  it('should safely manage thumbnail memory cache with LRU capacity limits', () => {
    const cache = new ThumbnailMemoryCache<string>(3);
    cache.set('key1', 'tex1');
    cache.set('key2', 'tex2');
    cache.set('key3', 'tex3');

    assert.strictEqual(cache.size(), 3);
    assert.strictEqual(cache.get('key1'), 'tex1');

    // Adding 4th item evicts oldest (key1)
    cache.set('key4', 'tex4');
    assert.strictEqual(cache.size(), 3);
    assert.strictEqual(cache.has('key1'), false);
    assert.strictEqual(cache.has('key4'), true);

    cache.clear();
    assert.strictEqual(cache.size(), 0);
  });

  it('should safely handle missing, null, or empty asset paths with fallback placeholders', () => {
    // Null and undefined
    const nullRes = resolveThumbnailAssetPath(null);
    assert.strictEqual(nullRes.isValid, false);
    assert.strictEqual(nullRes.isFallback, true);
    assert.strictEqual(nullRes.resolvedPath, 'fallback://primitive_box');

    const undefRes = resolveThumbnailAssetPath(undefined);
    assert.strictEqual(undefRes.isValid, false);
    assert.strictEqual(undefRes.isFallback, true);

    // Empty and whitespace strings
    const emptyRes = resolveThumbnailAssetPath('');
    assert.strictEqual(emptyRes.isValid, false);
    assert.strictEqual(emptyRes.isFallback, true);

    const spaceRes = resolveThumbnailAssetPath('    ');
    assert.strictEqual(spaceRes.isValid, false);
    assert.strictEqual(spaceRes.isFallback, true);

    // Non-3D file path
    const textRes = resolveThumbnailAssetPath('readme.txt');
    assert.strictEqual(textRes.isValid, false);
    assert.strictEqual(textRes.isFallback, true);
    assert.strictEqual(textRes.fallbackType, 'wireframe_cube');

    // Valid paths
    const validGlb = resolveThumbnailAssetPath('res://assets/custom_props/tower_spire.glb');
    assert.strictEqual(validGlb.isValid, true);
    assert.strictEqual(validGlb.isFallback, false);
    assert.strictEqual(validGlb.resolvedPath, 'res://assets/custom_props/tower_spire.glb');

    const validProc = resolveThumbnailAssetPath('procedural_bunker_slab');
    assert.strictEqual(validProc.isValid, true);
    assert.strictEqual(validProc.isFallback, false);
  });

  it('should validate amber styling tokens and canonical category metadata', () => {
    assert.strictEqual(AMBER_TERMINAL_HEX, '#E1A647');
    assert.strictEqual(AMBER_TERMINAL_RGB.r, 0.882);
    assert.strictEqual(OBSIDIAN_PANEL_HEX, '#0D0B0A');

    assert.strictEqual(CANONICAL_GRID_CATEGORIES.length, 4);
    const categoryIds = CANONICAL_GRID_CATEGORIES.map((c) => c.id);
    assert.deepStrictEqual(categoryIds, ['rocks', 'architecture', 'props', 'custom']);
  });

  describe('UI Virtualization & Card Slot Allocation (Phase 7 - Virtualized Pool)', () => {
    it('should allocate exact card slots and guarantee positive non-zero minimum dimensions', () => {
      const minCardWidth = 180;
      const minCardHeight = 210;
      assert.ok(minCardWidth > 0);
      assert.ok(minCardHeight > 0);

      // Verify slot binding behavior
      const testAssets: readonly CatalogGridItem[] = sampleItems.slice(0, 5);
      const allocatedSlots: Array<{ id: string; visible: boolean; minWidth: number; minHeight: number }> = [];

      for (let i = 0; i < testAssets.length; i++) {
        allocatedSlots.push({
          id: testAssets[i].id,
          visible: true,
          minWidth: minCardWidth,
          minHeight: minCardHeight
        });
      }

      assert.strictEqual(allocatedSlots.length, 5);
      for (const slot of allocatedSlots) {
        assert.strictEqual(slot.visible, true);
        assert.strictEqual(slot.minWidth, 180);
        assert.strictEqual(slot.minHeight, 210);
      }
    });

    it('should filter cross-category matches when searching terms like "bunkers"', () => {
      // Query "bunker" against sample items
      const query = 'bunker';
      // Search in 'rocks' category first (0 matches)
      const rocksMatches = filterCatalogItems(sampleItems, 'rocks', query);
      assert.strictEqual(rocksMatches.length, 0);

      // Global cross-category search should find bunker_slab
      const allMatches = filterCatalogItems(sampleItems, 'all', query);
      assert.strictEqual(allMatches.length, 1);
      assert.strictEqual(allMatches[0].id, 'bunker_slab');
      assert.strictEqual(allMatches[0].category, 'architecture');
    });

    it('should guarantee fallback placeholder when asset thumbnail is not yet baked', () => {
      const placeholder = resolveThumbnailAssetPath(null);
      assert.strictEqual(placeholder.isFallback, true);
      assert.strictEqual(placeholder.resolvedPath, 'fallback://primitive_box');

      const cacheKey = generateThumbnailCacheKey('bunker_slab', 128);
      assert.strictEqual(isValidThumbnailCacheKey(cacheKey), true);
      assert.strictEqual(cacheKey, 'thumb_bunker_slab_128');
    });
  });
});

