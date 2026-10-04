import type { Database } from "@/types/database"

/**
 * Measurement templates: which measurements each kind of item has.
 *
 * A category points to a template (categories.measurement_template). The
 * admin product form shows these fields for each size, and the storefront
 * size guide shows the same ones. Values are stored on each variant in
 * variants.measurements, e.g. { "waist": 41, "inseam": 80 }.
 *
 * - "length" fields are stored in centimetres and can be shown in inches.
 * - "label" fields (ring size, shoe size) are shown exactly as entered.
 * - Widths are measured flat across, the way you'd measure on a table.
 */

export type MeasurementTemplate = Database["public"]["Enums"]["measurement_template"]

export type MeasurementField = {
  key: string
  label: string
  kind: "length" | "label"
  hint?: string
  /** Sets have two tables: one for the top, one for the bottom */
  group?: "top" | "bottom"
}

type Template = { label: string; fields: MeasurementField[] }

const length = (key: string, label: string, hint?: string, group?: MeasurementField["group"]): MeasurementField => ({
  key,
  label,
  kind: "length",
  hint,
  group,
})

const sizeLabel = (key: string, label: string, hint?: string): MeasurementField => ({ key, label, kind: "label", hint })

const FLAT = "Measured flat, side to side"

export const MEASUREMENT_TEMPLATES: Record<MeasurementTemplate, Template> = {
  long_bottoms: {
    label: "Jeans & long bottoms",
    fields: [
      length("waist", "Waist", `${FLAT}, across the top of the waistband`),
      length("hip", "Hip", `${FLAT}, at the widest point`),
      length("front_rise", "Front rise", "Crotch seam to the top of the waistband"),
      length("thigh", "Thigh", `${FLAT}, just below the crotch`),
      length("knee", "Knee", `${FLAT}, halfway down the inseam`),
      length("leg_opening", "Leg opening", `${FLAT}, at the hem`),
      length("inseam", "Inseam", "Crotch seam to hem"),
      length("outseam", "Outseam", "Top of waistband to hem, down the side"),
    ],
  },
  shorts: {
    label: "Shorts",
    fields: [
      length("waist", "Waist", `${FLAT}, across the top of the waistband`),
      length("hip", "Hip", `${FLAT}, at the widest point`),
      length("front_rise", "Front rise", "Crotch seam to the top of the waistband"),
      length("thigh", "Thigh", `${FLAT}, just below the crotch`),
      length("leg_opening", "Leg opening", `${FLAT}, at the hem`),
      length("inseam", "Inseam", "Crotch seam to hem"),
    ],
  },
  tops: {
    label: "Tops & outerwear",
    fields: [
      length("chest", "Chest", "Pit to pit, measured flat"),
      length("length", "Length", "Top of the shoulder to the hem"),
      length("shoulder", "Shoulder", "Shoulder seam to shoulder seam"),
      length("sleeve", "Sleeve", "Shoulder seam to cuff"),
    ],
  },
  skirts_dresses: {
    label: "Skirts & dresses",
    fields: [
      length("waist", "Waist", FLAT),
      length("hip", "Hip", `${FLAT}, at the widest point`),
      length("length", "Length", "Top to hem"),
    ],
  },
  sets: {
    label: "Sets",
    fields: [
      length("top_chest", "Chest", "Pit to pit, measured flat", "top"),
      length("top_length", "Length", "Top of the shoulder to the hem", "top"),
      length("top_shoulder", "Shoulder", "Shoulder seam to shoulder seam", "top"),
      length("top_sleeve", "Sleeve", "Shoulder seam to cuff", "top"),
      length("bottom_waist", "Waist", FLAT, "bottom"),
      length("bottom_hip", "Hip", `${FLAT}, at the widest point`, "bottom"),
      length("bottom_inseam", "Inseam", "Crotch seam to hem (leave empty for skirts)", "bottom"),
      length("bottom_length", "Length", "Top of waistband to hem", "bottom"),
    ],
  },
  necklaces: {
    label: "Necklaces & pendants",
    fields: [
      length("length", "Length", "End to end, including the clasp"),
      length("thickness", "Thickness", "Width of the chain"),
      length("pendant_size", "Pendant size", "Height of the pendant"),
    ],
  },
  bracelets: {
    label: "Bracelets & anklets",
    fields: [length("length", "Length", "End to end, including the clasp"), length("width", "Width")],
  },
  rings: {
    label: "Rings",
    fields: [sizeLabel("ring_size", "Ring size", "e.g. US 8"), length("inner_diameter", "Inner diameter")],
  },
  earrings: {
    label: "Earrings",
    fields: [length("drop_length", "Drop length", "From the ear hole to the bottom"), length("width", "Width")],
  },
  belts: {
    label: "Belts",
    fields: [
      length("total_length", "Total length", "Buckle included"),
      length("width", "Width"),
      length("fits_waist_min", "Fits waist from", "Waist all the way round, smallest hole"),
      length("fits_waist_max", "Fits waist to", "Waist all the way round, largest hole"),
    ],
  },
  caps_bags: {
    label: "Caps & bags",
    fields: [length("width", "Width"), length("height", "Height"), length("depth", "Depth")],
  },
  footwear: {
    label: "Footwear",
    fields: [sizeLabel("eu_size", "EU size"), sizeLabel("uk_size", "UK size"), length("insole_length", "Insole length")],
  },
  none: { label: "No measurements", fields: [] },
}

/** A subcategory with no template of its own uses its parent's. */
export function resolveTemplate(
  category: { measurement_template: MeasurementTemplate | null },
  parent?: { measurement_template: MeasurementTemplate | null } | null,
): MeasurementTemplate {
  return category.measurement_template ?? parent?.measurement_template ?? "none"
}
