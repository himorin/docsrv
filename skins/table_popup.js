function dst_show_panel (obj) {
  popup_jsoncall(obj.target.id);
  YAHOO.dst.container.panel1.show();
}

function popup_jsoncall (target) {
  var tad = target.split('_');
  var url = 'json.cgi?format=json';
  url += '&id=' + tad[1];
  url += '&type=' + tad[0] + 'info';
  YAHOO.util.Connect.asyncRequest('GET', url, popup_callback);
}

var popup_callback = {
  success: function (o) {
    var messages = [];
    try { messages = YAHOO.lang.JSON.parse(o.responseText); }
    catch (x) { alert("YUI: Invalid JSON data"); return; }
    var pmes;
    if (messages.type == undefined) {
      pmes = "Execute failed.";
    } else {
      if (messages.type == "docinfo") {
        pmes  = "ID: path = " + messages.data.pathid;
        pmes += ", document = " + messages.data.docid;
        pmes += "<br>Name: " + messages.data.filename;
        pmes += "<br>Description: " + messages.data.short_description;
        pmes += "<br>Secure: " + messages.data.secure;
        pmes += "<br>Groups: " + messages.data.gname.join(", ");
        pmes += "<br>Labels: " + messages.data.labelid.join(", ");
        pmes += "<br>Last uploaded file";
        pmes += "<br> - User: " + messages.data.lastfile.uname;
        pmes += "<br> - File ID: " + messages.data.lastfile.fileid;
        pmes += "<br> - Description: " + messages.data.lastfile.description;
        pmes += "<br> - Type: " + messages.data.lastfile.fileext;
        pmes += "<br> - Size: " + messages.data.lastfile.size;
        pmes += "<br> - Date: " + messages.data.lastfile.uptime;
      } else if (messages.type == "pathinfo") {
        pmes += "ID: path = " + messages.data.pathid;
        pmes += ", parent = " + messages.data.parent;
        pmes += "<br>Name: " + messages.data.pathname;
        pmes += "<br>Description: " + messages.data.short_description;
        pmes += "<br>Groups: " + messages.data.gname.join(", ");
      }
    }
    YAHOO.dst.container.panel1.setBody(pmes);
  },
  failure: function (o) {
    if (! YAHOO.util.Connect.isCallInProgress(o)) {
      alert("YUI: Async call failed");
    }
  },
  timeout: 3000,
}
