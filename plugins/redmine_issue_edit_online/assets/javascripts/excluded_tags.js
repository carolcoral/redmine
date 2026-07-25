(function(){
  function createTag(text){
    const tag = document.createElement('span');
    tag.className = 'excluded-tag';
    tag.textContent = text;
    const rem = document.createElement('button');
    rem.type = 'button';
    rem.className = 'remove-tag';
    rem.innerHTML = '&#10006;';
    rem.addEventListener('click', function(){
      tag.parentNode.removeChild(tag);
      syncInput();
    });
    tag.appendChild(rem);
    return tag;
  }

  function syncInput(){
    const container = document.getElementById('excluded_tags_container');
    const input = document.getElementById('settings_excluded_field_id');
    if(!input) return;
    const values = Array.from(container.querySelectorAll('.excluded-tag')).map(t => t.firstChild.textContent.trim());
    input.value = values.join(',');
  }

  function init(){
    const input = document.getElementById('settings_excluded_field_id');
    const container = document.getElementById('excluded_tags_container');
    if(!input || !container) return;

    // create an input for adding
    const addInput = document.createElement('input');
    addInput.type = 'text';
    addInput.className = 'add-tag-input';
    addInput.placeholder = 'Add tag and press Enter';
    addInput.addEventListener('keydown', function(e){
      if(e.key === 'Enter'){
        e.preventDefault();
        const val = addInput.value.trim();
        if(val){ container.appendChild(createTag(val)); addInput.value = ''; syncInput(); }
      }
    });
    container.appendChild(addInput);

    // populate from initial value
    const initial = input.value ? input.value.split(',').map(s=>s.trim()).filter(Boolean) : [];
    initial.forEach(function(v){ container.appendChild(createTag(v)); });
    
  }

  document.addEventListener('DOMContentLoaded', init);
})();