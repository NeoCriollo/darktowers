/**
 * Localization Synchronization & Hardcoded String Elimination Test Suite
 * Phase 1.2: Unification of Localization & Eradication of Hardcoded Strings
 *
 * Verifies 1:1 key parity between English and Spanish GDScript dictionaries,
 * checks registry contract validity, and confirms zero hardcoded user-facing
 * strings remain in gameplay scripts and UI modals.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  PHASE_1_2_REGISTRY,
  LocalizationSyncValidator,
} from '../world/localizationSync.ts';

const REPO_ROOT = process.cwd();

describe('Phase 1.2: Localization Parity & Eradication of Hardcoded Strings', () => {
  const enPath = path.join(REPO_ROOT, 'localization', 'strings_en.gd');
  const esPath = path.join(REPO_ROOT, 'localization', 'strings_es.gd');

  it('should ensure both strings_en.gd and strings_es.gd exist on disk', () => {
    assert.ok(fs.existsSync(enPath), 'localization/strings_en.gd must exist');
    assert.ok(fs.existsSync(esPath), 'localization/strings_es.gd must exist');
  });

  it('should guarantee 100% mathematical key parity between strings_en.gd and strings_es.gd', () => {
    const enContent = fs.readFileSync(enPath, 'utf-8');
    const esContent = fs.readFileSync(esPath, 'utf-8');

    const enMap = LocalizationSyncValidator.parseGDScriptDictionary(enContent);
    const esMap = LocalizationSyncValidator.parseGDScriptDictionary(esContent);

    assert.ok(enMap.size > 0, 'strings_en.gd must contain localization keys');
    assert.ok(esMap.size > 0, 'strings_es.gd must contain localization keys');

    const parity = LocalizationSyncValidator.validateParity(enMap, esMap);

    assert.deepEqual(
      parity.missingInEs,
      [],
      `Keys present in English but missing in Spanish: ${parity.missingInEs.join(', ')}`
    );
    assert.deepEqual(
      parity.missingInEn,
      [],
      `Keys present in Spanish but missing in English: ${parity.missingInEn.join(', ')}`
    );
    assert.equal(
      parity.totalEnKeys,
      parity.totalEsKeys,
      `Total key counts must match identically (${parity.totalEnKeys} vs ${parity.totalEsKeys})`
    );
    assert.equal(parity.isSynchronized, true, 'Dictionaries must be fully synchronized');
  });

  it('should guarantee all Phase 1.2 target keys exist in strings_en.gd and strings_es.gd', () => {
    const enContent = fs.readFileSync(enPath, 'utf-8');
    const esContent = fs.readFileSync(esPath, 'utf-8');

    const enMap = LocalizationSyncValidator.parseGDScriptDictionary(enContent);
    const esMap = LocalizationSyncValidator.parseGDScriptDictionary(esContent);

    const requiredKeys = Object.keys(PHASE_1_2_REGISTRY);
    assert.ok(requiredKeys.length >= 7, 'Phase 1.2 must track at least 7 primary keys');

    for (const key of requiredKeys) {
      assert.ok(
        enMap.has(key),
        `Required key "${key}" must exist in localization/strings_en.gd`
      );
      assert.ok(
        esMap.has(key),
        `Required key "${key}" must exist in localization/strings_es.gd`
      );
      assert.ok(
        enMap.get(key)!.length > 0,
        `English translation for "${key}" cannot be empty`
      );
      assert.ok(
        esMap.get(key)!.length > 0,
        `Spanish translation for "${key}" cannot be empty`
      );
    }
  });

  it('should verify world/thinny_zone.gd routes banner text through Localization.t("THINNY_ZONE_BANNER")', () => {
    const thinnyPath = path.join(REPO_ROOT, 'world', 'thinny_zone.gd');
    assert.ok(fs.existsSync(thinnyPath), 'world/thinny_zone.gd must exist');
    const content = fs.readFileSync(thinnyPath, 'utf-8');

    assert.ok(
      content.includes('THINNY_ZONE_BANNER'),
      'world/thinny_zone.gd must reference THINNY_ZONE_BANNER'
    );
    assert.ok(
      content.includes('Localization.t('),
      'world/thinny_zone.gd must call Localization.t()'
    );

    // Hardcoded raw string banner must NOT be emitted directly to notify_region_change
    assert.ok(
      !content.includes('notify_region_change("ANOMALÍA ESPACIO-TEMPORAL [THINNY]")'),
      'world/thinny_zone.gd must not have hardcoded raw banner notification'
    );
  });

  it('should verify world/midworld_doorway.gd routes doorway title through Localization.t("MIDWORLD_DOORWAY_PRISONER")', () => {
    const doorwayPath = path.join(REPO_ROOT, 'world', 'midworld_doorway.gd');
    assert.ok(fs.existsSync(doorwayPath), 'world/midworld_doorway.gd must exist');
    const content = fs.readFileSync(doorwayPath, 'utf-8');

    assert.ok(
      content.includes('MIDWORLD_DOORWAY_PRISONER'),
      'world/midworld_doorway.gd must reference MIDWORLD_DOORWAY_PRISONER'
    );
    assert.ok(
      content.includes('Localization.t('),
      'world/midworld_doorway.gd must call Localization.t()'
    );
  });

  it('should verify ui/pause_menu.gd routes editor save toasts and sunny day override through Localization.t()', () => {
    const pauseMenuPath = path.join(REPO_ROOT, 'ui', 'pause_menu.gd');
    assert.ok(fs.existsSync(pauseMenuPath), 'ui/pause_menu.gd must exist');
    const content = fs.readFileSync(pauseMenuPath, 'utf-8');

    assert.ok(
      content.includes('EDITOR_TOAST_SAVE'),
      'ui/pause_menu.gd must reference EDITOR_TOAST_SAVE'
    );
    assert.ok(
      content.includes('EDITOR_TOAST_SUNNY'),
      'ui/pause_menu.gd must reference EDITOR_TOAST_SUNNY'
    );
    assert.ok(
      content.includes('PAUSE_HEADER_TITLE'),
      'ui/pause_menu.gd must reference PAUSE_HEADER_TITLE'
    );

    // Ensure raw unlocalized strings were eliminated
    assert.ok(
      !content.includes('"[ ARQUITECTO ] DISEÑO DE MUNDO GUARDADO EN WORLD_LAYOUT_OVERRIDES.JSON"'),
      'ui/pause_menu.gd must not contain raw hardcoded save toast'
    );
    assert.ok(
      !content.includes('"☀ LUZ DE DÍA MÁXIMA: " + ("ACTIVADA'),
      'ui/pause_menu.gd must not contain raw hardcoded sunny day toggle message'
    );
  });

  it('should verify ui/inventory_and_journal_modal.gd routes journal chapters through Localization.t()', () => {
    const journalPath = path.join(REPO_ROOT, 'ui', 'inventory_and_journal_modal.gd');
    assert.ok(fs.existsSync(journalPath), 'ui/inventory_and_journal_modal.gd must exist');
    const content = fs.readFileSync(journalPath, 'utf-8');

    assert.ok(
      content.includes('JOURNAL_CHAPTER_1_TITLE'),
      'ui/inventory_and_journal_modal.gd must reference JOURNAL_CHAPTER_1_TITLE'
    );
    assert.ok(
      content.includes('JOURNAL_CHAPTER_1_DESC'),
      'ui/inventory_and_journal_modal.gd must reference JOURNAL_CHAPTER_1_DESC'
    );
    assert.ok(
      content.includes('Localization.t('),
      'ui/inventory_and_journal_modal.gd must invoke Localization.t()'
    );

    // Ensure raw hardcoded Spanish strings were eliminated from the journal data array
    assert.ok(
      !content.includes('"title": "EL COMIENZO DEL CAMINO"'),
      'ui/inventory_and_journal_modal.gd must not contain raw hardcoded chapter title'
    );
    assert.ok(
      !content.includes('"text": "Atraviesa el Desierto de Mohaine'),
      'ui/inventory_and_journal_modal.gd must not contain raw hardcoded chapter description'
    );
  });

  it('should verify player/player_hazard_effects.gd routes loot toasts through Localization.t("HAZARD_LOOT_NOTIFICATION")', () => {
    const hazardPath = path.join(REPO_ROOT, 'player', 'player_hazard_effects.gd');
    assert.ok(fs.existsSync(hazardPath), 'player/player_hazard_effects.gd must exist');
    const content = fs.readFileSync(hazardPath, 'utf-8');

    assert.ok(
      content.includes('HAZARD_LOOT_NOTIFICATION'),
      'player/player_hazard_effects.gd must reference HAZARD_LOOT_NOTIFICATION'
    );
    assert.ok(
      content.includes('Localization.t('),
      'player/player_hazard_effects.gd must call Localization.t()'
    );

    // Ensure raw unlocalized formatting string was eliminated
    assert.ok(
      !content.includes('"%s: +%d .45 LC | +%d CHATARRA" %'),
      'player/player_hazard_effects.gd must not contain raw hardcoded CHATARRA format string'
    );
  });
});
