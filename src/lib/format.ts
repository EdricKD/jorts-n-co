// Formatting helpers shared by the storefront and admin.

const NBSP = " " // keeps "GH₵" and the amount on the same line

/** 25000 → "GH₵ 250", 25050 → "GH₵ 250.50" */
export function formatCedis(pesewas: number): string {
  const showPesewas = pesewas % 100 !== 0
  const amount = (pesewas / 100).toLocaleString("en-GH", {
    minimumFractionDigits: showPesewas ? 2 : 0,
    maximumFractionDigits: 2,
  })
  return `GH₵${NBSP}${amount}`
}

/** "250" or "250.50" typed in a form → 25000 / 25050. Returns null if it isn't a valid amount. */
export function cedisToPesewas(input: string): number | null {
  const cleaned = input.replace(/[,\s]/g, "").replace(/^GH₵/i, "")
  if (!/^\d+(\.\d{1,2})?$/.test(cleaned)) return null
  return Math.round(Number(cleaned) * 100)
}

/** Measurements are stored in cm. Inches are rounded to the nearest quarter. */
export function cmToInches(cm: number): number {
  return Math.round((cm / 2.54) * 4) / 4
}

/**
 * Normalises the ways people type Ghana mobile numbers to +233XXXXXXXXX.
 * "024 123 4567", "0241234567", "+233 24 123 4567", "233241234567" all work.
 * Returns null if it isn't a Ghana mobile number.
 */
export function normalizeGhanaPhone(input: string): string | null {
  let digits = input.replace(/[^\d+]/g, "")

  if (digits.startsWith("+233")) digits = digits.slice(4)
  else if (digits.startsWith("00233")) digits = digits.slice(5)
  else if (digits.startsWith("233") && digits.length === 12) digits = digits.slice(3)
  else if (digits.startsWith("0") && digits.length === 10) digits = digits.slice(1)

  // Mobile numbers (MTN, Telecel, AirtelTigo) start with 2 or 5 after the 0
  return /^[25]\d{8}$/.test(digits) ? `+233${digits}` : null
}

/** Pop-up times in Ghana time: "Fri 10 Oct, 2:00 pm – 6:00 pm" */
export function formatPopupTime(startsAt: string, endsAt: string): string {
  const zone = { timeZone: "Africa/Accra" } as const
  const day = new Date(startsAt).toLocaleDateString("en-GB", { ...zone, weekday: "short", day: "numeric", month: "short" })
  const time = (iso: string) =>
    new Date(iso).toLocaleTimeString("en-GB", { ...zone, hour: "numeric", minute: "2-digit", hour12: true })
  return `${day}, ${time(startsAt)} – ${time(endsAt)}`
}

/** "+233241234567" → "024 123 4567" */
export function formatGhanaPhone(e164: string): string {
  const local = `0${e164.replace(/^\+233/, "")}`
  return `${local.slice(0, 3)} ${local.slice(3, 6)} ${local.slice(6)}`
}
