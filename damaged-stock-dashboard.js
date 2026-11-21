/* =========================================================
   BIG BROTHER
   DAMAGED STOCK DASHBOARD MENU V3

   MENU:
   - Damaged Stock Report
   - Cleared Damaged Stock
   - Damage Accounting & Recovery
   ========================================================= */

(function () {

  "use strict";


  /* =========================================================
     INSTALL MENU
     ========================================================= */

  function installDamagedStockMenu() {


    const oldButton =
      document.getElementById(
        "navStockDamaged"
      );


    if (
      !oldButton
    ) {

      return;

    }



    /* =====================================================
       ROUTES
       ===================================================== */

    if (
      typeof MODULE_URLS !==
      "undefined"
    ) {


      MODULE_URLS[
        "stock-damaged-report"
      ] =
        "https://angsokhey11-cloud.github.io/big-brother-damaged-stock/?embed=1&v=2";


      MODULE_URLS[
        "stock-damaged-cleared"
      ] =
        "https://angsokhey11-cloud.github.io/big-brother-damaged-stock/cleared.html?embed=1&v=3";


      MODULE_URLS[
        "stock-damaged-accounting"
      ] =
        "https://angsokhey11-cloud.github.io/big-brother-damaged-stock/accounting.html?embed=1&v=4";


    }



    /* =====================================================
       MENU GROUP
       ===================================================== */

    const group =
      document.createElement(
        "div"
      );


    group.className =
      "nested-nav-group";


    group.id =
      "damagedStockNavGroup";


    group.innerHTML = `

      <button

        type="button"

        id="damagedStockMenuButton"

        class="nested-nav-toggle"

        aria-expanded="false"

      >

        <span class="nested-nav-main">

          <span>
            ⚠️
          </span>

          <span>
            Damaged Stock
          </span>

        </span>


        <span class="nav-arrow">
          ▼
        </span>

      </button>


      <div

        id="damagedStockSubmenu"

        class="
          nav-submenu
          nav-submenu-level2
        "

      >


        <button

          type="button"

          id="navStockDamagedReport"

        >

          📊 Damaged Stock Report

        </button>


        <button

          type="button"

          id="navStockDamagedCleared"

        >

          ✅ Cleared Damaged Stock

        </button>


        <button

          type="button"

          id="navStockDamagedAccounting"

        >

          💰 Damage Accounting
          &amp; Recovery

        </button>


      </div>

    `;


    oldButton.replaceWith(
      group
    );



    /* =====================================================
       TOGGLE DAMAGED STOCK GROUP
       ===================================================== */

    const toggle =
      document.getElementById(
        "damagedStockMenuButton"
      );


    const submenu =
      document.getElementById(
        "damagedStockSubmenu"
      );


    toggle.addEventListener(

      "click",

      function () {


        const open =
          submenu
            .classList
            .contains(
              "open"
            );


        submenu.classList.toggle(
          "open",
          !open
        );


        toggle.classList.toggle(
          "open",
          !open
        );


        toggle.setAttribute(
          "aria-expanded",
          String(
            !open
          )
        );


        const arrow =
          toggle.querySelector(
            ".nav-arrow"
          );


        if (
          arrow
        ) {

          arrow.textContent =
            open
              ? "▼"
              : "▲";

        }


      }

    );



    /* =====================================================
       DAMAGED STOCK REPORT
       ===================================================== */

    document
      .getElementById(
        "navStockDamagedReport"
      )
      .addEventListener(

        "click",

        function () {


          openModule(

            "stock-damaged-report",

            "navStockDamagedReport"

          );


        }

      );



    /* =====================================================
       CLEARED DAMAGED STOCK
       ===================================================== */

    document
      .getElementById(
        "navStockDamagedCleared"
      )
      .addEventListener(

        "click",

        function () {


          openModule(

            "stock-damaged-cleared",

            "navStockDamagedCleared"

          );


        }

      );



    /* =====================================================
       DAMAGE ACCOUNTING & RECOVERY
       ===================================================== */

    document
      .getElementById(
        "navStockDamagedAccounting"
      )
      .addEventListener(

        "click",

        function () {


          openModule(

            "stock-damaged-accounting",

            "navStockDamagedAccounting"

          );


        }

      );


  }



  /* =========================================================
     OPEN WORKSPACE
     ========================================================= */

  function openModule(
    route,
    activeId
  ) {


    if (
      typeof loadWorkspace !==
      "function"
    ) {

      return;

    }


    loadWorkspace(
      route
    );



    /* =====================================================
       KEEP STOCK MENU OPEN
       ===================================================== */

    const stockSub =
      document.getElementById(
        "stockSubmenu"
      );


    const stockBtn =
      document.getElementById(
        "stockMenuButton"
      );


    if (
      stockSub
    ) {

      stockSub
        .classList
        .add(
          "open"
        );

    }


    if (
      stockBtn
    ) {


      stockBtn
        .classList
        .add(
          "open"
        );


      stockBtn.setAttribute(
        "aria-expanded",
        "true"
      );


    }



    /* =====================================================
       KEEP DAMAGED STOCK MENU OPEN
       ===================================================== */

    const damagedSub =
      document.getElementById(
        "damagedStockSubmenu"
      );


    const damagedBtn =
      document.getElementById(
        "damagedStockMenuButton"
      );


    if (
      damagedSub
    ) {

      damagedSub
        .classList
        .add(
          "open"
        );

    }


    if (
      damagedBtn
    ) {


      damagedBtn
        .classList
        .add(
          "open"
        );


      damagedBtn.setAttribute(
        "aria-expanded",
        "true"
      );


      const arrow =
        damagedBtn.querySelector(
          ".nav-arrow"
        );


      if (
        arrow
      ) {

        arrow.textContent =
          "▲";

      }


    }



    /* =====================================================
       ACTIVE CHILD
       ===================================================== */

    [

      "navStockDamagedReport",

      "navStockDamagedCleared",

      "navStockDamagedAccounting"

    ].forEach(

      id => {


        document
          .getElementById(
            id
          )
          ?.classList
          .remove(
            "active"
          );


      }

    );


    document
      .getElementById(
        activeId
      )
      ?.classList
      .add(
        "active"
      );


  }



  /* =========================================================
     RESTORE NESTED SIDEBAR STATE ON FULL REFRESH
     ========================================================= */

  const damagedRouteButtons = {
    "stock-damaged-report": "navStockDamagedReport",
    "stock-damaged-cleared": "navStockDamagedCleared",
    "stock-damaged-accounting": "navStockDamagedAccounting"
  };

  function expandMenu(subId, buttonId) {
    const sub = document.getElementById(subId);
    const button = document.getElementById(buttonId);
    if (sub) sub.classList.add("open");
    if (button) {
      button.classList.add("open");
      button.setAttribute("aria-expanded", "true");
      const arrow = button.querySelector(".nav-arrow");
      if (arrow) arrow.textContent = "▲";
    }
  }

  function showActiveDamageRoute(route) {
    const activeId = damagedRouteButtons[route];
    if (!activeId || !document.getElementById(activeId)) return;

    // The original shell only knows stock-damaged, not its three child routes.
    // Keep both parent groups expanded and mark the precise route selected.
    expandMenu("stockSubmenu", "stockMenuButton");
    expandMenu("damagedStockSubmenu", "damagedStockMenuButton");

    document.querySelectorAll(".shell-nav-link.active, .nav-submenu button.active")
      .forEach(button => button.classList.remove("active"));
    document.getElementById(activeId)?.classList.add("active");
  }

  function restoreDamageMenuFromUrl() {
    const route = new URLSearchParams(location.search).get("module");
    if (route && damagedRouteButtons[route]) showActiveDamageRoute(route);
  }

  function installDamageMenuActiveBridge() {
    const original = window.setShellActive;
    if (typeof original !== "function" || original.__bbDamageMenuActiveBridge) return;
    const enhanced = function (moduleName) {
      const result = original.apply(this, arguments);
      showActiveDamageRoute(moduleName);
      return result;
    };
    enhanced.__bbDamageMenuActiveBridge = true;
    window.setShellActive = enhanced;
  }

  /* =========================================================
     START
     ========================================================= */

  installDamagedStockMenu();
  installDamageMenuActiveBridge();
  restoreDamageMenuFromUrl();
  // The authorized Dashboard route can finish opening after DOMContentLoaded.
  // Re-apply the highlight once its iframe loads, without reloading the app.
  document.getElementById("moduleFrame")
    ?.addEventListener("load", restoreDamageMenuFromUrl);


})();
