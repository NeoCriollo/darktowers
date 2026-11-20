/**
 * Localization Synchronization & Parity Contracts — "Dark Towers: The Path of Ka"
 * Phase 1.2: Unification of Localization & Eradication of Hardcoded Strings
 *
 * Provides TypeScript domain mirrors for dual-language dictionaries (EN/ES),
 * ensures 1:1 key parity between `strings_en.gd` and `strings_es.gd`, and provides
 * static verification helpers to detect raw unlocalized strings in game scripts.
 */

export type SupportedLanguage = 'en' | 'es';

export type LocalizationCategory =
  | 'ANOMALIES'
  | 'DOORWAYS'
  | 'EDITOR'
  | 'JOURNAL'
  | 'INVENTORY'
  | 'BALLISTICS'
  | 'HAZARDS'
  | 'PAUSE_MENU';

export interface LocalizationEntry {
  key: string;
  category: LocalizationCategory;
  en: string;
  es: string;
  description: string;
}

/**
 * Registry of Phase 1.2 localized strings with mirrored English and Spanish definitions.
 */
export const PHASE_1_2_REGISTRY: Record<string, LocalizationEntry> = {
  THINNY_ZONE_BANNER: {
    key: 'THINNY_ZONE_BANNER',
    category: 'ANOMALIES',
    en: 'SPACE-TIME ANOMALY [THINNY]',
    es: 'ANOMALÍA ESPACIO-TEMPORAL [THINNY]',
    description: 'Header notification banner triggered when crossing into thinny boundaries.',
  },
  MIDWORLD_DOORWAY_PRISONER: {
    key: 'MIDWORLD_DOORWAY_PRISONER',
    category: 'DOORWAYS',
    en: 'THE PRISONER / LA PRISIONERA',
    es: 'LA PRISIONERA / THE PRISONER',
    description: 'Dimensional doorway title drawn from Stephen King The Drawing of the Three.',
  },
  EDITOR_TOAST_SAVE: {
    key: 'EDITOR_TOAST_SAVE',
    category: 'EDITOR',
    en: '[ ARCHITECT ] WORLD LAYOUT SAVED TO WORLD_LAYOUT_OVERRIDES.JSON',
    es: '[ ARQUITECTO ] DISEÑO DE MUNDO GUARDADO EN WORLD_LAYOUT_OVERRIDES.JSON',
    description: 'Confirmation toast upon saving world layout editor overrides.',
  },
  EDITOR_TOAST_SAVE_ERR: {
    key: 'EDITOR_TOAST_SAVE_ERR',
    category: 'EDITOR',
    en: '[ ERROR ] FAILED TO SAVE WORLD LAYOUT',
    es: '[ ERROR ] NO SE PUDO GUARDAR EL DISEÑO DEL MUNDO',
    description: 'Error toast when failing to save world layout.',
  },
  EDITOR_TOAST_SUNNY: {
    key: 'EDITOR_TOAST_SUNNY',
    category: 'EDITOR',
    en: '☀ MAXIMUM DAYLIGHT: %s',
    es: '☀ LUZ DE DÍA MÁXIMA: %s',
    description: 'Toast feedback when toggling clear sunny daylight override.',
  },
  EDITOR_SUNNY_ACTIVE: {
    key: 'EDITOR_SUNNY_ACTIVE',
    category: 'EDITOR',
    en: 'ACTIVATED (3.5x SOLAR / NO FOG)',
    es: 'ACTIVADA (3.5x SOLAR / SIN NIEBLA)',
    description: 'Sub-status string for active sunny day override.',
  },
  EDITOR_SUNNY_INACTIVE: {
    key: 'EDITOR_SUNNY_INACTIVE',
    category: 'EDITOR',
    en: 'DEACTIVATED (ATMOSPHERE RESTORED)',
    es: 'DESACTIVADA (ATMÓSFERA RESTAURADA)',
    description: 'Sub-status string for restored atmospheric conditions.',
  },
  BTN_SUNNY_DAY: {
    key: 'BTN_SUNNY_DAY',
    category: 'EDITOR',
    en: 'MAXIMUM DAYLIGHT (SUNNY DAY)',
    es: 'LUZ DE DÍA MÁXIMA (SUNNY DAY)',
    description: 'Button text for the sunny day override toggle in editor pause menu.',
  },
  STATE_ACTIVATED: {
    key: 'STATE_ACTIVATED',
    category: 'EDITOR',
    en: 'ACTIVATED',
    es: 'ACTIVADA',
    description: 'State label for active system state.',
  },
  STATE_DEACTIVATED: {
    key: 'STATE_DEACTIVATED',
    category: 'EDITOR',
    en: 'DEACTIVATED',
    es: 'DESACTIVADA',
    description: 'State label for inactive system state.',
  },
  PAUSE_HEADER_TITLE: {
    key: 'PAUSE_HEADER_TITLE',
    category: 'PAUSE_MENU',
    en: '◆ TACTICAL PAUSE — THE PATH OF THE BEAM',
    es: '◆ PAUSA TÁCTICA — SISTEMA DEL HAZ',
    description: 'Header text for tactical pause menu modal.',
  },
  PAUSE_MODE_SUBTITLE_FMT: {
    key: 'PAUSE_MODE_SUBTITLE_FMT',
    category: 'PAUSE_MENU',
    en: 'ACTIVE SESSION: %s  |  ENTER / ESC TO RESUME',
    es: 'SESIÓN ACTIVA: %s  |  ENTER / ESC PARA CONTINUAR',
    description: 'Session subtitle formatting showing current mode.',
  },
  PAUSE_MODE_EDITOR: {
    key: 'PAUSE_MODE_EDITOR',
    category: 'PAUSE_MENU',
    en: 'ARCHITECT MODE (EDITOR)',
    es: 'MODO ARQUITECTO (EDITOR)',
    description: 'Label for Architect / World Editor session mode.',
  },
  PAUSE_MODE_SURVIVAL: {
    key: 'PAUSE_MODE_SURVIVAL',
    category: 'PAUSE_MENU',
    en: 'SURVIVAL MODE',
    es: 'MODO SUPERVIVENCIA',
    description: 'Label for Survival gameplay session mode.',
  },
  PAUSE_BTN_RESUME: {
    key: 'PAUSE_BTN_RESUME',
    category: 'PAUSE_MENU',
    en: '[•] RESUME (CONTINUE)',
    es: '[•] CONTINUAR (RESUME)',
    description: 'Pause menu button to resume gameplay.',
  },
  PAUSE_BTN_SAVE: {
    key: 'PAUSE_BTN_SAVE',
    category: 'PAUSE_MENU',
    en: '[•] SAVE WORLD',
    es: '[•] GUARDAR MUNDO (SAVE WORLD)',
    description: 'Pause menu button to save world overrides.',
  },
  PAUSE_BTN_SETTINGS: {
    key: 'PAUSE_BTN_SETTINGS',
    category: 'PAUSE_MENU',
    en: '[•] SETTINGS',
    es: '[•] AJUSTES (SETTINGS)',
    description: 'Pause menu button to open audio/video/tactical settings.',
  },
  PAUSE_BTN_HELP: {
    key: 'PAUSE_BTN_HELP',
    category: 'PAUSE_MENU',
    en: '[•] FIELD GUIDE / DEV TOOLS',
    es: '[•] GUÍA RÁPIDA / DEV TOOLS',
    description: 'Pause menu button to open field controls guide.',
  },
  PAUSE_BTN_EXIT: {
    key: 'PAUSE_BTN_EXIT',
    category: 'PAUSE_MENU',
    en: '[•] MAIN MENU (EXIT TO MENU)',
    es: '[•] MENÚ PRINCIPAL (EXIT TO MENU)',
    description: 'Pause menu button to exit back to title menu.',
  },
  JOURNAL_TITLE: {
    key: 'JOURNAL_TITLE',
    category: 'JOURNAL',
    en: 'KA LOGBOOK',
    es: 'DIARIO DE KA',
    description: 'Diegetic Gunslinger journal and logbook header.',
  },
  JOURNAL_CHAPTER_1_TITLE: {
    key: 'JOURNAL_CHAPTER_1_TITLE',
    category: 'JOURNAL',
    en: 'THE START OF THE PATH',
    es: 'EL COMIENZO DEL CAMINO',
    description: 'Opening quest log chapter title.',
  },
  JOURNAL_CHAPTER_1_DESC: {
    key: 'JOURNAL_CHAPTER_1_DESC',
    category: 'JOURNAL',
    en: 'Cross the Mohaine Desert in search of the Man in Black. The Dark Tower awaits at the nexus of time.',
    es: 'Atraviesa el Desierto de Mohaine en busca del Hombre de Negro. La Torre Oscura aguarda en el nexo del tiempo.',
    description: 'Opening quest log narrative summary.',
  },
  JOURNAL_CHAPTER_2_TITLE: {
    key: 'JOURNAL_CHAPTER_2_TITLE',
    category: 'JOURNAL',
    en: 'WEAPON LOGBOOK',
    es: 'REGISTRO DE ARMAS',
    description: 'Second logbook chapter title for ballistics and weapon care.',
  },
  JOURNAL_CHAPTER_2_DESC: {
    key: 'JOURNAL_CHAPTER_2_DESC',
    category: 'JOURNAL',
    en: 'Tuned sandalwood frontier revolver. Guard against unburnt carbon fouling and caliche grit seizing the cylinder.',
    es: 'Revólver de culata de sándalo afinado. Cuidado con el hollín y la arena caliche que traban el tambor.',
    description: 'Second logbook entry text describing cylinder maintenance.',
  },
  JOURNAL_CAT_MAIN_QUEST: {
    key: 'JOURNAL_CAT_MAIN_QUEST',
    category: 'JOURNAL',
    en: 'MAIN MISSION',
    es: 'MISIÓN PRINCIPAL',
    description: 'Category tag for main storyline quest entries.',
  },
  JOURNAL_CAT_BALLISTICS: {
    key: 'JOURNAL_CAT_BALLISTICS',
    category: 'BALLISTICS',
    en: 'BALLISTICS',
    es: 'BALÍSTICA',
    description: 'Category tag for gunsmithing and ballistics entries.',
  },
  JOURNAL_TIME_DAY_1_DUSK: {
    key: 'JOURNAL_TIME_DAY_1_DUSK',
    category: 'JOURNAL',
    en: 'Day 1, Twilight',
    es: 'Día 1, Crepúsculo',
    description: 'Timestamp for the twilight of Day 1 in Mid-World.',
  },
  JOURNAL_TIME_DAY_1_NIGHT: {
    key: 'JOURNAL_TIME_DAY_1_NIGHT',
    category: 'JOURNAL',
    en: 'Day 1, Night',
    es: 'Día 1, Noche',
    description: 'Timestamp for the night of Day 1 in Mid-World.',
  },
  JOURNAL_TIME_RECENT: {
    key: 'JOURNAL_TIME_RECENT',
    category: 'JOURNAL',
    en: 'Recent Log',
    es: 'Registro Reciente',
    description: 'Timestamp fallback for dynamic user-discovered entries.',
  },
  NOTIF_JOURNAL_ADDED_FMT: {
    key: 'NOTIF_JOURNAL_ADDED_FMT',
    category: 'JOURNAL',
    en: '◇ Logbook entry recorded: %s',
    es: '◇ Entrada de Diario añadida: %s',
    description: 'Toast notification format when a new logbook entry is unlocked.',
  },
  NOTIF_INVENTORY_OPENED: {
    key: 'NOTIF_INVENTORY_OPENED',
    category: 'INVENTORY',
    en: '◇ Tactical Inventory Opened',
    es: '◇ Inventario Táctico Abierto',
    description: 'Toast feedback when opening tactical inventory grid.',
  },
  NOTIF_SADDLEBAG_TRANSFERRED_FMT: {
    key: 'NOTIF_SADDLEBAG_TRANSFERRED_FMT',
    category: 'INVENTORY',
    en: '◇ Stowed in mount saddlebag: %s (x%d)',
    es: '◇ Transferido a alforjas de montura: %s (x%d)',
    description: 'Toast notification when stowing items into mount storage.',
  },
  NOTIF_SADDLEBAG_RETRIEVED_FMT: {
    key: 'NOTIF_SADDLEBAG_RETRIEVED_FMT',
    category: 'INVENTORY',
    en: '◇ Retrieved from saddlebag: %s (x%d)',
    es: '◇ Recuperado de alforjas: %s (x%d)',
    description: 'Toast notification when taking items out of mount storage.',
  },
  ENCUMBRANCE_OVERBURDENED_FMT: {
    key: 'ENCUMBRANCE_OVERBURDENED_FMT',
    category: 'INVENTORY',
    en: 'OVERBURDENED (%.1f / %.1f kg)',
    es: 'SOBRECARGADO (%.1f / %.1f kg)',
    description: 'Status label when pack mass exceeds max carry capacity.',
  },
  ENCUMBRANCE_HEAVY_FMT: {
    key: 'ENCUMBRANCE_HEAVY_FMT',
    category: 'INVENTORY',
    en: 'HEAVY (%.1f / %.1f kg)',
    es: 'PESADO (%.1f / %.1f kg)',
    description: 'Status label when pack mass exceeds 75% carry capacity.',
  },
  ENCUMBRANCE_LIGHT_FMT: {
    key: 'ENCUMBRANCE_LIGHT_FMT',
    category: 'INVENTORY',
    en: 'AGILE (%.1f / %.1f kg)',
    es: 'ÁGIL (%.1f / %.1f kg)',
    description: 'Status label when pack mass is optimal.',
  },
  ITEM_UNKNOWN: {
    key: 'ITEM_UNKNOWN',
    category: 'INVENTORY',
    en: 'Unknown Item',
    es: 'Objeto Desconocido',
    description: 'Fallback item name in tooltips.',
  },
  ITEM_CAT_SUPPLIES: {
    key: 'ITEM_CAT_SUPPLIES',
    category: 'INVENTORY',
    en: 'SUPPLIES',
    es: 'SUMINISTROS',
    description: 'General category for consumable supplies in inventory slots.',
  },
  ITEM_TOOLTIP_FMT: {
    key: 'ITEM_TOOLTIP_FMT',
    category: 'INVENTORY',
    en: '%s [%s]\nMass: %.2f kg | Condition: %d%%\n%s',
    es: '%s [%s]\nMasa: %.2f kg | Condición: %d%%\n%s',
    description: 'Multiline formatting pattern for inventory item slot tooltips.',
  },
  HAZARD_LOOT_NOTIFICATION: {
    key: 'HAZARD_LOOT_NOTIFICATION',
    category: 'HAZARDS',
    en: '%s: +%d .45 LC | +%d SCRAP',
    es: '%s: +%d .45 LC | +%d CHATARRA',
    description: 'HUD region toast displayed when looting field supply crates.',
  },
  LOOT_SUPPLY_CACHE: {
    key: 'LOOT_SUPPLY_CACHE',
    category: 'HAZARDS',
    en: 'SUPPLY CACHE',
    es: 'CACHÉ DE SUMINISTROS',
    description: 'Default label for unopened wasteland supply crates.',
  },
};

/**
 * Localization Parity Validator and static string analyzer.
 */
export class LocalizationSyncValidator {
  /**
   * Parses GDScript localization dictionary file content into a Map of key -> value.
   */
  public static parseGDScriptDictionary(content: string): Map<string, string> {
    const result = new Map<string, string>();
    const lineRegex = /^\s*"([A-Za-z0-9_]+)":\s*"((?:\\.|[^"\\])*)"/gm;
    let match: RegExpExecArray | null;

    while ((match = lineRegex.exec(content)) !== null) {
      const key = match[1];
      const val = match[2];
      result.set(key, val);
    }
    return result;
  }

  /**
   * Validates key parity between English and Spanish GDScript dictionary maps.
   */
  public static validateParity(
    enMap: Map<string, string>,
    esMap: Map<string, string>
  ): {
    missingInEs: string[];
    missingInEn: string[];
    totalEnKeys: number;
    totalEsKeys: number;
    isSynchronized: boolean;
  } {
    const missingInEs: string[] = [];
    const missingInEn: string[] = [];

    for (const key of enMap.keys()) {
      if (!esMap.has(key)) {
        missingInEs.push(key);
      }
    }

    for (const key of esMap.keys()) {
      if (!enMap.has(key)) {
        missingInEn.push(key);
      }
    }

    return {
      missingInEs,
      missingInEn,
      totalEnKeys: enMap.size,
      totalEsKeys: esMap.size,
      isSynchronized: missingInEs.length === 0 && missingInEn.length === 0,
    };
  }

  /**
   * Scans a file's content for exact target unlocalized string literals.
   * Returns a list of occurrences detected.
   */
  public static detectRawStringLiterals(
    fileContent: string,
    unlocalizedPatterns: RegExp[]
  ): string[] {
    const detected: string[] = [];
    for (const pattern of unlocalizedPatterns) {
      if (pattern.test(fileContent)) {
        detected.push(pattern.source);
      }
    }
    return detected;
  }

  /**
   * Checks whether the file content invokes `Localization.t(key)` for a given key.
   */
  public static hasLocalizationLookup(fileContent: string, key: string): boolean {
    const pattern = new RegExp(`Localization\\.t\\(\\s*["']${key}["']\\s*\\)`);
    return pattern.test(fileContent);
  }

  /**
   * Translates a registered key using the TypeScript registry.
   */
  public static translate(key: string, lang: SupportedLanguage): string | undefined {
    const entry = PHASE_1_2_REGISTRY[key];
    if (!entry) return undefined;
    return lang === 'es' ? entry.es : entry.en;
  }
}

