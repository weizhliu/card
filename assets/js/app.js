// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// ===================================
// PHOENIX LIVEVIEW HOOKS
// ===================================

let Hooks = {}

// Card Play Animation Hook
// Triggers animation when a card is played from hand to desk
Hooks.CardPlay = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      // Add pressed effect
      this.el.classList.add("scale-95", "opacity-75")

      // Create a flying card clone for animation
      const card = this.el.querySelector(".game-card") || this.el
      const clone = card.cloneNode(true)
      const rect = card.getBoundingClientRect()

      clone.style.position = "fixed"
      clone.style.top = `${rect.top}px`
      clone.style.left = `${rect.left}px`
      clone.style.width = `${rect.width}px`
      clone.style.height = `${rect.height}px`
      clone.style.zIndex = "9999"
      clone.style.pointerEvents = "none"
      clone.style.transition = "all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)"

      document.body.appendChild(clone)

      // Animate to desk area (center of screen, slightly up)
      requestAnimationFrame(() => {
        const targetY = window.innerHeight * 0.35
        const targetX = window.innerWidth / 2 - rect.width / 2

        clone.style.top = `${targetY}px`
        clone.style.left = `${targetX}px`
        clone.style.transform = "scale(1.1) rotateY(10deg)"
        clone.style.opacity = "0"
      })

      // Remove clone after animation
      setTimeout(() => {
        clone.remove()
        this.el.classList.remove("scale-95", "opacity-75")
      }, 400)
    })
  }
}

// Desk Card Animation Hook
// Animates cards as they appear on the desk
Hooks.DeskCard = {
  mounted() {
    // Add entrance animation
    this.el.classList.add("desk-card")

    // Track previous card count for new card detection
    this.cardCount = this.el.querySelectorAll(".game-card").length
  },

  updated() {
    const newCount = this.el.querySelectorAll(".game-card").length

    // If new cards were added, animate them
    if (newCount > this.cardCount) {
      const cards = this.el.querySelectorAll(".game-card")
      const newCards = Array.from(cards).slice(this.cardCount)

      newCards.forEach((card, index) => {
        card.style.animation = "none"
        card.offsetHeight // Trigger reflow
        card.style.animation = `cardPlace 0.4s cubic-bezier(0.34, 1.56, 0.64, 1) ${index * 0.1}s both`
      })
    }

    this.cardCount = newCount
  }
}

// Round Indicator Hook
// Pulses and highlights when round changes
Hooks.RoundIndicator = {
  mounted() {
    this.currentRound = this.el.dataset.round
    this.el.classList.add("round-indicator")
  },

  updated() {
    const newRound = this.el.dataset.round

    if (newRound !== this.currentRound) {
      // Trigger round change animation
      this.el.classList.remove("new-round")
      void this.el.offsetWidth // Trigger reflow
      this.el.classList.add("new-round")

      // Flash effect on the entire game area
      this.pushEvent("round_changed", {round: newRound})

      // Remove animation class after completion
      setTimeout(() => {
        this.el.classList.remove("new-round")
      }, 1500)

      this.currentRound = newRound
    }
  }
}

// Turn Progress Hook
// Shows visual progress through the turn
Hooks.TurnProgress = {
  mounted() {
    this.currentTurn = parseInt(this.el.dataset.turn) || 1
    this.maxTurns = parseInt(this.el.dataset.maxTurns) || 3
    this.updateProgress()
  },

  updated() {
    const newTurn = parseInt(this.el.dataset.turn) || 1
    if (newTurn !== this.currentTurn) {
      this.currentTurn = newTurn
      this.animateProgress()
    }
  },

  updateProgress() {
    const progress = (this.currentTurn / this.maxTurns) * 100
    const bar = this.el.querySelector(".turn-indicator")
    if (bar) {
      bar.style.width = `${progress}%`
    }
  },

  animateProgress() {
    const bar = this.el.querySelector(".turn-indicator")
    if (bar) {
      bar.classList.add("transition-all", "duration-500")
      this.updateProgress()
    }
  }
}

// Win Celebration Hook
// Creates particle effects on win
Hooks.WinCelebration = {
  mounted() {
    if (this.el.dataset.winner === "true") {
      this.celebrate()
    }
  },

  updated() {
    if (this.el.dataset.winner === "true") {
      this.celebrate()
    }
  },

  celebrate() {
    this.el.classList.add("celebrate-win")
    this.createParticles()
  },

  createParticles() {
    const colors = ["#3b82f6", "#22c55e", "#eab308", "#ec4899", "#8b5cf6"]
    const particleCount = 20

    for (let i = 0; i < particleCount; i++) {
      const particle = document.createElement("div")
      particle.className = "confetti-particle"
      particle.style.cssText = `
        position: absolute;
        width: 8px;
        height: 8px;
        background: ${colors[Math.floor(Math.random() * colors.length)]};
        border-radius: ${Math.random() > 0.5 ? "50%" : "0"};
        pointer-events: none;
        left: 50%;
        top: 50%;
        z-index: 100;
      `

      this.el.appendChild(particle)

      // Animate particle
      const angle = (Math.PI * 2 * i) / particleCount
      const velocity = 50 + Math.random() * 100
      const targetX = Math.cos(angle) * velocity
      const targetY = Math.sin(angle) * velocity - 50

      particle.animate([
        { transform: "translate(-50%, -50%) scale(0)", opacity: 1 },
        { transform: `translate(calc(-50% + ${targetX}px), calc(-50% + ${targetY}px)) scale(1)`, opacity: 1, offset: 0.3 },
        { transform: `translate(calc(-50% + ${targetX * 1.5}px), calc(-50% + ${targetY * 1.5 + 100}px)) scale(0)`, opacity: 0 }
      ], {
        duration: 1000 + Math.random() * 500,
        easing: "cubic-bezier(0, 0.5, 0.5, 1)"
      }).onfinish = () => particle.remove()
    }
  }
}

// Card Flip Hook
// Animates card flip reveal
Hooks.CardFlip = {
  mounted() {
    this.observed = false
  },

  updated() {
    const shouldFlip = this.el.dataset.flip === "true"

    if (shouldFlip && !this.observed) {
      this.el.classList.add("card-flip")
      this.observed = true

      setTimeout(() => {
        this.el.classList.remove("card-flip")
        this.observed = false
      }, 600)
    }
  }
}

// Hand Card Stagger Animation Hook
// Animates cards dealing into hand with stagger
Hooks.HandCards = {
  mounted() {
    this.animateCards()
  },

  updated() {
    // Check for new cards
    const cards = this.el.querySelectorAll(".hand-card")
    cards.forEach((card, index) => {
      if (!card.dataset.animated) {
        card.style.animation = `cardPlace 0.4s cubic-bezier(0.34, 1.56, 0.64, 1) ${index * 0.05}s both`
        card.dataset.animated = "true"
      }
    })
  },

  animateCards() {
    const cards = this.el.querySelectorAll(".hand-card")
    cards.forEach((card, index) => {
      card.style.opacity = "0"
      card.style.transform = "translateY(20px) scale(0.9)"

      setTimeout(() => {
        card.style.transition = "all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)"
        card.style.opacity = "1"
        card.style.transform = "translateY(0) scale(1)"
        card.dataset.animated = "true"
      }, 100 + index * 80)
    })
  }
}

// Tilt Card on Hover Hook
// Adds 3D tilt effect based on mouse position
Hooks.CardTilt = {
  mounted() {
    this.el.addEventListener("mousemove", (e) => this.handleTilt(e))
    this.el.addEventListener("mouseleave", () => this.resetTilt())
  },

  handleTilt(e) {
    const rect = this.el.getBoundingClientRect()
    const x = e.clientX - rect.left
    const y = e.clientY - rect.top
    const centerX = rect.width / 2
    const centerY = rect.height / 2

    const rotateX = (y - centerY) / 10
    const rotateY = (centerX - x) / 10

    this.el.style.transform = `perspective(500px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.05)`
  },

  resetTilt() {
    this.el.style.transform = ""
  }
}

// Game Status Flash Hook
// Flashes the game area on significant events
Hooks.GameFlash = {
  mounted() {
    this.handleEvent("game_flash", ({type}) => {
      this.flash(type)
    })
  },

  flash(type) {
    const colors = {
      win: "rgba(34, 197, 94, 0.2)",
      lose: "rgba(239, 68, 68, 0.2)",
      round: "rgba(59, 130, 246, 0.2)",
      turn: "rgba(168, 85, 247, 0.1)"
    }

    const overlay = document.createElement("div")
    overlay.style.cssText = `
      position: fixed;
      inset: 0;
      background: ${colors[type] || colors.turn};
      pointer-events: none;
      z-index: 9998;
    `

    document.body.appendChild(overlay)

    overlay.animate([
      { opacity: 1 },
      { opacity: 0 }
    ], {
      duration: 500,
      easing: "ease-out"
    }).onfinish = () => overlay.remove()
  }
}

// ===================================
// END HOOKS
// ===================================

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Custom Phoenix events for game effects
window.addEventListener("phx:card-played", (e) => {
  // Trigger card play sound or additional effects
  console.log("Card played:", e.detail)
})

window.addEventListener("phx:round-changed", (e) => {
  // Trigger round change flash
  const flash = document.createElement("div")
  flash.className = "fixed inset-0 bg-blue-500/10 pointer-events-none z-50"
  flash.style.animation = "fadeIn 0.3s ease-out reverse"
  document.body.appendChild(flash)
  setTimeout(() => flash.remove(), 300)
})

window.addEventListener("phx:game-over", (e) => {
  const {winner} = e.detail
  if (winner) {
    // Could trigger celebration effects here
    console.log("Game over - winner:", winner)
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

