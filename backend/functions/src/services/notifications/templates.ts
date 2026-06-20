export type TemplateKey =
  | "new_order"
  | "order_preparing"
  | "order_ready"
  | "courier_assigned"
  | "order_picked_up"
  | "order_on_route"
  | "order_delivered"
  | "order_cancelled";

export function renderTemplate(key: TemplateKey, vars: Record<string, any>) {
  switch (key) {
    case "new_order":
      return { title: "New order", body: `New order ${vars.orderId} received${vars.restaurantName ? ` at ${vars.restaurantName}` : ""}` };
    case "order_preparing":
      return { title: "Preparing", body: `Restaurant started preparing order ${vars.orderId}` };
    case "order_ready":
      return { title: "Ready for pickup", body: `Order ${vars.orderId} is ready` };
    case "courier_assigned":
      return { title: "Courier assigned", body: `Courier on the way for order ${vars.orderId}${vars.etaMinutes ? `, ETA ~${vars.etaMinutes} min` : ""}` };
    case "order_picked_up":
      return { title: "Picked up", body: `Courier picked up order ${vars.orderId}` };
    case "order_on_route":
      return { title: "On route", body: `Courier en route to you for order ${vars.orderId}${vars.etaMinutes ? `, ETA ~${vars.etaMinutes} min` : ""}` };
    case "order_delivered":
      return { title: "Delivered", body: `Order ${vars.orderId} delivered` };
    case "order_cancelled":
      return { title: "Cancelled", body: `Order ${vars.orderId} was cancelled` };
    default:
      return { title: "", body: "" };
  }
}


