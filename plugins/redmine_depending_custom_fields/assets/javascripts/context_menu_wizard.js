(function(){
  let current = null; // {menu, container, outside, onSubmit, form}

  document.addEventListener('DOMContentLoaded', () => {
    ensureContainer();

    const obs = new MutationObserver(setupMenu);
    obs.observe(document.body, { subtree:true, childList:true, attributes:true, attributeFilter:['style'] });
    setupMenu();

    function ensureContainer(){
      let c = document.getElementById('cf-wizard-container');
      if(!c){
        c = document.createElement('div');
        c.id = 'cf-wizard-container';
        c.className = 'context-menu cf-wizard';
        c.style.display = 'none';
        document.body.appendChild(c);
      }
      return c;
    }

    function setupMenu(){
      const menu = document.getElementById('context-menu');
      if(!menu){ return; }

      if(!menu.dataset.dcfInit){
        adjustWidth(menu);
        menu.addEventListener('click', e => {
          const a = e.target.closest('li.cf-parent > a.submenu');
          if(!a) return;
          const li = a.closest('li.cf-parent');
          const tId = li ? li.dataset.templateId : null;
          if(!tId) return;
          e.preventDefault(); e.stopPropagation();
          const tmpl = document.getElementById(tId);
          if(!tmpl) return;
          openWizard(menu, tmpl, li);
        });
        menu.dataset.dcfInit = '1';
      }
    }

    function adjustWidth(menu){
      menu.classList.add('cf-has-wizard');
      menu.style.width = 'auto';
      menu.style.maxWidth = 'none';
    }

    function openWizard(menu, tmpl, item){
      closeWizard();
      const container = ensureContainer();
      container.innerHTML = '';
      container.appendChild(tmpl.content.cloneNode(true));
      if(window.DependingCustomFields &&
         typeof window.DependingCustomFields.requestSetup === 'function'){
        window.DependingCustomFields.requestSetup(container);
      }
      positionContainer(container, menu, item);
      container.style.display = 'block';

      const form = container.querySelector('form');
      const onMenuHover = e => {
        if(!item.contains(e.target)) closeWizard();
      };
      menu.addEventListener('mouseover', onMenuHover);

      const outside = e => {
        if(!container.contains(e.target)){
          closeWizard();
        }
      };
      document.addEventListener('mousedown', outside);

      const stopProp = e => e.stopPropagation();
      ['mousedown','mouseup','click','contextmenu']
        .forEach(ev=>container.addEventListener(ev, stopProp));

      const onSubmit = e => {
        e.preventDefault();
        submitForm(form).then(() => closeWizard());
      };
      if(form) form.addEventListener('submit', onSubmit);

      current = { container, outside, onSubmit, form, stopProp, menu, onMenuHover, item };
    }

    function positionContainer(container, menu, item){
      const menuRect = menu.getBoundingClientRect();
      const itemRect = item ? item.getBoundingClientRect() : menuRect;
      container.style.position = 'absolute';
      container.style.top = (itemRect.top + window.scrollY) + 'px';
      container.style.left = (menuRect.right + window.scrollX + 2) + 'px';
    }

    function closeWizard(){
      if(!current) return;
      const { container, outside, onSubmit, form, stopProp, menu, onMenuHover } = current;
      container.style.display = 'none';
      container.innerHTML = '';
      document.removeEventListener('mousedown', outside);
      if(form) form.removeEventListener('submit', onSubmit);
      ['mousedown','mouseup','click','contextmenu']
        .forEach(ev=>container.removeEventListener(ev, stopProp));
      if(menu) menu.removeEventListener('mouseover', onMenuHover);
      current = null;
    }

    function submitForm(form){
      if(!form) return Promise.resolve();
      const params = new URLSearchParams(new FormData(form));
      const url = (window.ContextMenuWizardConfig.basePath || '') + '/depending_custom_fields/save';
      return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
      }).then(res => {
        if(res.ok){
          window.location.reload();
        } else {
          res.json().then(data => {
            const msgs = (data && data.errors) ? data.errors.join('\n') : res.statusText;
            alert(msgs);
          });
          throw new Error('save failed');
        }
      });
    }
  });
})();
