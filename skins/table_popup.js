function dst_show_panel (obj) {
  popup_jsoncall(obj.target.id);
  YAHOO.dst.container.enttbldi.cfg.setProperty("x", obj.pageX + 50);
  YAHOO.dst.container.enttbldi.cfg.setProperty("y", obj.pageY + 50);
  YAHOO.dst.container.enttbldi.show();
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
        pmes += "<br>Name: ";
        var ppid = 0;
        while (ppid != messages.data.pathid) {
          pmes += "/<a href=\"pathinfo.cgi?pid=" + messages.data.parr[ppid].pid + "\">" + messages.data.parr[ppid].name + "</a>";
          ppid = messages.data.parr[ppid].pid;
        }
        pmes += "/" + messages.data.filename;
        pmes += "<br>Description: " + messages.data.short_description;
        pmes += "<br>Secure: " + messages.data.secure;
        pmes += "<br>Groups: " + messages.data.gname.join(", ");
        pmes += "<br>Labels: " + messages.data.labelid.join(", ");
        pmes += "<br>Avail formats: ";
        for (var i = 0; i < messages.data.exts.length; i++) {
          pmes += "<a href=\"fileget.cgi?did=" + messages.data.docid + "&ext=";
          pmes += messages.data.exts[i] + "\">" + messages.data.exts[i];
          pmes += "</a> | ";
        }
        pmes += " (download newest per each format)";
        pmes += "<br>Last uploaded file";
        pmes += "<br> - User: " + messages.data.lastfile.uname;
        pmes += "<br> - File ID: " + messages.data.lastfile.fileid;
        pmes += "<br> - Description: " + messages.data.lastfile.description;
        pmes += "<br> - Type: " + messages.data.lastfile.fileext;
        pmes += "<br> - Size: " + messages.data.lastfile.size;
        pmes += "<br> - Date: " + messages.data.lastfile.uptime;
      } else if (messages.type == "pathinfo") {
        pmes  = "ID: path = " + messages.data.pathid;
        pmes += ", parent = " + messages.data.parent;
        pmes += "<br>Name: ";
        var ppid = 0;
        while (ppid != messages.data.pathid) {
          pmes += "/<a href=\"pathinfo.cgi?pid=" + messages.data.parr[ppid].pid + "\">" + messages.data.parr[ppid].name + "</a>";
          ppid = messages.data.parr[ppid].pid;
        }
        pmes += "<br>Description: " + messages.data.short_description;
        pmes += "<br>Groups: " + messages.data.gname.join(", ");
      }
      // attribute table
      pmes += "<br>Attributes:";
      pmes += "<table border=1><thead><th>key</th><th>value</th></thead><tbody>";
      for (var i in messages.data.attr) {
        pmes += "<tr><td>" + i + "</td><td>" + messages.data.attr[i] + "</td></tr>";
      }
      pmes += "</tbody></table>";
    }
    YAHOO.dst.container.enttbldi.setBody(pmes);
  },
  failure: function (o) {
    if (! YAHOO.util.Connect.isCallInProgress(o)) {
      alert("YUI: Async call failed");
    }
  },
  timeout: 3000,
}

