// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import { initFlowbite } from "flowbite"
import "flowbite-datepicker"

// Initialize Flowbite on initial page load
document.addEventListener("DOMContentLoaded", () => {
  initFlowbite()
})

// Re-initialize Flowbite after Turbo navigation
document.addEventListener("turbo:load", () => {
  initFlowbite()
})

// Re-initialize Flowbite after Turbo renders a frame
document.addEventListener("turbo:render", () => {
  initFlowbite()
})