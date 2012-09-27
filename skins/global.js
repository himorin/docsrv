// general toggle class

function tweak_ToggleClass (target, css) {
  var elem = YAHOO.util.Dom.getElementsByClassName(target);
  for (var i = 0; i < elem.length; i++) {
    if (YAHOO.util.Dom.hasClass(elem[i], css)) {YAHOO.util.Dom.removeClass(elem[i], css); }
    else {YAHOO.util.Dom.addClass(elem[i], css); }
  }
}

// favorite

var fav_callback = {
  success: function (o) {
    var messages = [];
    try { messages = YAHOO.lang.JSON.parse(o.responseText); }
    catch (x) { alert("YUI: Invalid JSON data"); }
    if (messages.fav == undefined) {
      alert("Exec failed." + o.responseText);
    } else {
      if (messages.fav.did == undefined) {
        if (messages.fav.pid == undefined) {
          alert("Invalid operation: no target");
          return;
        }
        // path mode
        var elem = document.getElementById('fav_p' + messages.fav.pid);
        if (elem == undefined) {
          alert("No such id " + messages.fav.pid);
        } else if (messages.fav.op == 'add') {
          YAHOO.util.Dom.addClass(elem, 'fav_on');
          elem.src = 'skins/images/woofunction/16/star.png';
        } else if (messages.fav.op == 'remove') {
          YAHOO.util.Dom.removeClass(elem, 'fav_on');
          elem.src = 'skins/images/woofunction/16/star_off.png';
        } else {
          alert('Invalid operation: ' + messages.fav.pid + ' / ' + messages.fav.op);
        }
      } else {
        // doc mode
        var elem = document.getElementById('fav_' + messages.fav.did);
        if (elem == undefined) {
          alert("No such id " + messages.fav.did);
        } else if (messages.fav.op == 'add') {
          YAHOO.util.Dom.addClass(elem, 'fav_on');
          elem.src = 'skins/images/woofunction/16/star.png';
        } else if (messages.fav.op == 'remove') {
          YAHOO.util.Dom.removeClass(elem, 'fav_on');
          elem.src = 'skins/images/woofunction/16/star_off.png';
        } else {
          alert('Invalid operation: ' + messages.fav.did + ' / ' + messages.fav.op);
        }
      }
    }
  },
  failure: function (o) {
    if (! YAHOO.util.Connect.isCallInProgress(o)) {
      alert("YUI: Async call failed");
    }
  },
  timeout: 3000,
}

function tweak_ToggleFav (target) {
  var elem = document.getElementById('fav_' + target);
  var url = 'docfav.cgi?format=json&did=' + target + '&op=';
  if (YAHOO.util.Dom.hasClass(elem, 'fav_on')) {url += 'remove'; } 
  else {url += 'add'; }
  YAHOO.util.Connect.asyncRequest('GET', url, fav_callback);
}

function tweak_ToggleFavPath (target) {
  var elem = document.getElementById('fav_p' + target);
  var url = 'docfav.cgi?format=json&pid=' + target + '&op=';
  if (YAHOO.util.Dom.hasClass(elem, 'fav_on')) {url += 'remove'; } 
  else {url += 'add'; }
  YAHOO.util.Connect.asyncRequest('GET', url, fav_callback);
}

function AllPathChange() {
  var selid = document.docadd_set.pid.selectedIndex;
  var hid = document.docadd_set.pid.options[selid].value;
  if (hid == 0) {
    document.getElementById("hid").innerHTML = 0;
    document.getElementById("fullpath").innerHTML = "";
    document.getElementById("desc").innerHTML = "Top Directory";
  } else {
    document.getElementById("hid").innerHTML = hid;
    document.getElementById("fullpath").innerHTML = conf_data_allpath.data[hid].fullpath;
    document.getElementById("desc").innerHTML = conf_data_allpath.data[hid].description;
  }
}


// InfoTip will use id 'gbit' element

var def_gbit_id = 'gbit';

function show_infotip_path(target) {
    document.getElementById(def_gbit_id).style.display = 'block';
}

function show_infotip_doc(target) {
    document.getElementById(def_gbit_id).style.display = 'block';
}

function hide_infotip() {
    document.getElementById(def_gbit_id).style.display = 'none';
}




