/**
 * Redmine AI Assistant - Chat Widget
 * 悬浮宠物图标 + AI 对话窗口（Vanilla JS，兼容 Redmine 7 Propshaft）
 */
(function () {
  "use strict";

  class AIChatWidget {
    constructor() {
      this.conversationId = this.generateId();
      this.isProcessing = false;
      this.csrfToken = "";

      this.elements = {};
      this.init();
    }

    init() {
      const container = document.getElementById("ai-chat-widget");
      if (!container) return;

      this.csrfToken = container.dataset.aiChatCsrfValue ||
        document.querySelector('meta[name="csrf-token"]')?.content || "";

      this.elements = {
        container: container,
        toggle: document.getElementById("ai-chat-toggle"),
        window: document.getElementById("ai-chat-window"),
        messages: document.getElementById("ai-chat-messages"),
        input: document.getElementById("ai-chat-input"),
        sendBtn: document.getElementById("ai-chat-send"),
        status: container.querySelector("[data-ai-chat-target='status']"),
        statusBar: container.querySelector("[data-ai-chat-target='statusBar']"),
      };

      this.bindEvents();
      container.setAttribute("aria-hidden", "false");
    }

    bindEvents() {
      const { toggle, input, sendBtn, window: win } = this.elements;

      // Toggle
      toggle.addEventListener("click", () => this.toggle());

      // Send
      sendBtn.addEventListener("click", () => this.sendMessage());
      input.addEventListener("keydown", (e) => this.handleKeydown(e));
      input.addEventListener("input", () => this.autoResize());

      // Close button in header
      const closeBtn = win?.querySelector("[data-action*='toggle']");
      if (closeBtn) closeBtn.addEventListener("click", () => this.toggle());

      // New conversation
      const newConvBtn = win?.querySelector("[data-action*='newConversation']");
      if (newConvBtn) newConvBtn.addEventListener("click", () => this.newConversation());

      // Report buttons
      const reportBtns = win?.querySelectorAll("[data-action*='generateReport']");
      reportBtns.forEach((btn) => {
        btn.addEventListener("click", (e) => this.generateReport(e));
      });

      // Quick ask buttons
      const quickBtns = win?.querySelectorAll("[data-action*='quickAsk']");
      quickBtns.forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const question = btn.dataset.question;
          if (question) { input.value = question; this.sendMessage(); }
        });
      });
    }

    // ========== Toggle ==========
    toggle() {
      const { toggle, window: win } = this.elements;
      const isOpen = !win.classList.contains("ai-chat-hidden");

      if (isOpen) {
        win.classList.add("ai-chat-hidden");
        win.style.display = "none";
        toggle.classList.remove("ai-chat-active");
      } else {
        win.classList.remove("ai-chat-hidden");
        win.style.display = "";
        toggle.classList.add("ai-chat-active");
        setTimeout(() => this.elements.input?.focus(), 300);
      }
    }

    // ========== Send Message ==========
    async sendMessage() {
      const { input } = this.elements;
      const message = input.value.trim();
      if (!message || this.isProcessing) return;

      input.value = "";
      input.style.height = "auto";
      this.setProcessing(true);
      this.appendMessage("user", message);

      try {
        const formData = new FormData();
        formData.append("message", message);
        formData.append("conversation_id", this.conversationId);

        const response = await fetch("/ai_assistant/chat/send_message", {
          method: "POST",
          headers: {
            "X-CSRF-Token": this.csrfToken,
            Accept: "application/json",
          },
          body: formData,
        });

        const data = await response.json();

        if (data.error) {
          this.appendMessage("assistant", "❌ " + data.error, true);
        } else {
          this.conversationId = data.conversation_id;
          this.appendMessage("assistant", data.message.content);
        }
      } catch (error) {
        this.appendMessage("assistant", "❌ 网络错误: " + error.message, true);
      } finally {
        this.setProcessing(false);
        this.scrollToBottom();
      }
    }

    // ========== Generate Report ==========
    async generateReport(event) {
      const btn = event.currentTarget;
      const reportType = btn.dataset.reportType;
      if (this.isProcessing) return;

      const labels = { daily: "日报", weekly: "周报", monthly: "月报" };
      this.setProcessing(true);
      this.appendMessage("user", "📝 生成" + (labels[reportType] || "报告") + "...");

      try {
        const formData = new FormData();
        formData.append("report_type", reportType);

        const response = await fetch("/ai_assistant/reports/generate", {
          method: "POST",
          headers: {
            "X-CSRF-Token": this.csrfToken,
            Accept: "application/json",
          },
          body: formData,
        });

        const data = await response.json();

        if (data.error) {
          this.appendMessage("assistant", "❌ " + data.error, true);
        } else {
          this.appendMessage("assistant", data.content);
        }
      } catch (error) {
        this.appendMessage("assistant", "❌ 报告生成失败: " + error.message, true);
      } finally {
        this.setProcessing(false);
        this.scrollToBottom();
      }
    }

    // ========== New Conversation ==========
    newConversation() {
      if (this.isProcessing) return;
      this.conversationId = this.generateId();
      const { messages } = this.elements;
      messages.innerHTML = "";
      this.showWelcomeMessage();
    }

    // ========== Keyboard ==========
    handleKeydown(event) {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        this.sendMessage();
      }
    }

    autoResize() {
      const el = this.elements.input;
      el.style.height = "auto";
      el.style.height = Math.min(el.scrollHeight, 150) + "px";
    }

    // ========== Render ==========
    appendMessage(role, content, isError) {
      isError = isError || false;
      const { messages } = this.elements;

      // Remove welcome
      const welcome = messages.querySelector(".ai-chat-welcome");
      if (welcome) welcome.remove();

      const div = document.createElement("div");
      div.className = "ai-chat-message ai-chat-" + role + (isError ? " ai-chat-error" : "");

      const avatar = role === "user" ? "👤" : "🤖";
      const label = role === "user" ? "You" : "AI";

      div.innerHTML =
        '<div class="ai-chat-message-avatar">' + avatar + "</div>" +
        '<div class="ai-chat-message-body">' +
          '<div class="ai-chat-message-label">' + label + "</div>" +
          '<div class="ai-chat-message-content">' + this.renderContent(content) + "</div>" +
        "</div>";

      messages.appendChild(div);
      this.scrollToBottom();
    }

    renderContent(content) {
      let html = this.escapeHtml(content);

      // Code blocks
      html = html.replace(/```(\w+)?\n([\s\S]*?)```/g, function (_, lang, code) {
        return '<pre><code class="language-' + (lang || "") + '">' + code.replace(/</g, "&lt;").replace(/>/g, "&gt;") + "</code></pre>";
      });

      // Inline code
      html = html.replace(/`([^`]+)`/g, "<code>$1</code>");

      // Bold
      html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");

      // Italic
      html = html.replace(/\*([^*]+)\*/g, "<em>$1</em>");

      // Headers
      html = html.replace(/^### (.+)$/gm, "<h3>$1</h3>");
      html = html.replace(/^## (.+)$/gm, "<h2>$1</h2>");

      // Lists
      html = html.replace(/^- (.+)$/gm, "<li>$1</li>");
      html = html.replace(/((?:<li>.*<\/li>\n?)+)/g, "<ul>$1</ul>");

      // Line breaks
      html = html.replace(/\n\n/g, "</p><p>");
      html = html.replace(/\n/g, "<br>");
      html = "<p>" + html + "</p>";

      return html;
    }

    escapeHtml(text) {
      const div = document.createElement("div");
      div.textContent = text;
      return div.innerHTML;
    }

    showWelcomeMessage() {
      const { messages } = this.elements;
      const div = document.createElement("div");
      div.className = "ai-chat-welcome";
      div.innerHTML =
        '<div class="ai-chat-welcome-icon">🤖</div>' +
        "<p>你好！我是 AI 助手。有什么可以帮你的？</p>" +
        '<p class="ai-chat-disclaimer">⚠️ 涉及业务数据时，我处于只读模式</p>';
      messages.appendChild(div);
    }

    setProcessing(processing) {
      this.isProcessing = processing;
      const { sendBtn, statusBar, status } = this.elements;

      if (processing) {
        sendBtn.disabled = true;
        if (statusBar) statusBar.style.display = "flex";
        if (status) status.textContent = "🟡";
      } else {
        sendBtn.disabled = false;
        if (statusBar) statusBar.style.display = "none";
        if (status) status.textContent = "🟢";
      }
    }

    scrollToBottom() {
      setTimeout(() => {
        const { messages } = this.elements;
        if (messages) messages.scrollTop = messages.scrollHeight;
      }, 50);
    }

    generateId() {
      return "conv_" + Date.now() + "_" + Math.random().toString(36).substring(2, 10);
    }
  }

  // ========== 初始化 ==========
  document.addEventListener("DOMContentLoaded", function () {
    window.aiChatWidget = new AIChatWidget();
  });

  // Turbo 页面切换支持
  document.addEventListener("turbo:load", function () {
    if (!window.aiChatWidget || !document.getElementById("ai-chat-widget")) {
      window.aiChatWidget = new AIChatWidget();
    }
  });
})();
