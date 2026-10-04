// =============================================================================
// TEMPORARY, hand-written stand-in.
//
// Once the project is linked to Supabase, `npm run db:types` replaces this
// file with types generated from the real database (every table and
// function). Only the tables Phase 1 reads are listed here, in the same shape
// the generator produces, so no other code changes when it's regenerated.
// =============================================================================

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

type Enums = {
  department: "men" | "women" | "unisex"
  fulfilment: "pickup" | "delivery"
  measurement_template:
    | "long_bottoms"
    | "shorts"
    | "tops"
    | "skirts_dresses"
    | "sets"
    | "necklaces"
    | "bracelets"
    | "rings"
    | "earrings"
    | "belts"
    | "caps_bags"
    | "footwear"
    | "none"
  order_status: "pending" | "confirmed" | "ready" | "completed" | "cancelled"
  payment_method: "cash" | "momo"
  payment_status: "unpaid" | "paid" | "refunded"
  product_status: "draft" | "active" | "archived"
  sales_channel: "online" | "popup"
  stock_reason: "restock" | "online_sale" | "popup_sale" | "adjustment" | "return" | "damaged" | "cancelled"
}

type Table<Row> = { Row: Row; Insert: Partial<Row>; Update: Partial<Row>; Relationships: [] }

export type Database = {
  public: {
    Tables: {
      categories: Table<{
        id: string
        name: string
        slug: string
        parent_id: string | null
        measurement_template: Enums["measurement_template"] | null
        sort_order: number
        created_at: string
      }>
      products: Table<{
        id: string
        code: number
        title: string
        slug: string
        description: string
        category_id: string
        department: Enums["department"]
        brand: string | null
        price: number
        compare_at_price: number | null
        status: Enums["product_status"]
        attributes: Json
        tags: string[]
        created_at: string
        updated_at: string
      }>
      variants: Table<{
        id: string
        product_id: string
        sku: string
        size_label: string
        colour: string | null
        position: number
        stock_qty: number
        low_stock_threshold: number
        measurements: Json
        created_at: string
        updated_at: string
      }>
      popups: Table<{
        id: string
        title: string
        location: string
        starts_at: string
        ends_at: string
        notes: string | null
        is_published: boolean
        created_at: string
      }>
      orders: Table<{
        id: string
        order_number: string
        public_token: string
        channel: Enums["sales_channel"]
        status: Enums["order_status"]
        customer_name: string | null
        phone: string | null
        fulfilment: Enums["fulfilment"]
        popup_id: string | null
        delivery_zone_id: string | null
        delivery_zone_name: string | null
        delivery_address: string | null
        payment_method: Enums["payment_method"]
        payment_status: Enums["payment_status"]
        payment_reference: string | null
        subtotal: number
        delivery_fee: number | null
        discount: number
        total: number
        notes: string | null
        cancelled_at: string | null
        created_at: string
        updated_at: string
      }>
    }
    Views: { [_ in never]: never }
    Functions: {
      is_admin: { Args: never; Returns: boolean }
    }
    Enums: Enums
    CompositeTypes: { [_ in never]: never }
  }
}
