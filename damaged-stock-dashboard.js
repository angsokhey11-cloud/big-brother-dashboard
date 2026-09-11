/* =========================================================
   BIG BROTHER
   DAMAGED STOCK DASHBOARD MENU V2
   ========================================================= */

(function () {

  "use strict";


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


    }



    /* =====================================================
       MENU HTML
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


      </div>

    `;


    oldButton.replaceWith(
      group
    );



    /* =====================================================
       TOGGLE
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
       DAMAGE REPORT
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
       CLEARED REPORT
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

      "navStockDamagedCleared"

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
     START
     ========================================================= */

  installDamagedStockMenu();


})();
