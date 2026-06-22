<#--
  Diametral email shell for Keycloak. Wraps every HTML email (password reset,
  verify email, execute actions, …) in the brand layout: a centered 600px white
  card with a 1px border, the Diametral wordmark over a 1px rule, and a faint
  footer — flat, no radius, system + serif fonts (mail clients won't load Geist
  or Ufficio). The per-email body is injected at <#nested>.
-->
<#macro emailLayout>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light only">
<style>
  a { color: #db2400; }
  p { margin: 0 0 16px; }
</style>
</head>
<body style="margin:0;padding:0;background:#f4f4f5;-webkit-text-size-adjust:100%;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;"><tr>
<td align="center" style="padding:28px 12px;">
  <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border:1px solid #e5e5e5;">
    <#-- Header: wordmark over a black rule -->
    <tr><td style="padding:20px 28px;border-bottom:1px solid #161616;">
      <span style="font-family:Georgia,'Times New Roman',serif;font-size:20px;color:#161616;">Diametral</span>
      <span style="font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:11px;letter-spacing:0.14em;text-transform:uppercase;color:#6c6f7d;">&nbsp;&nbsp;Account</span>
    </td></tr>
    <#-- Body: the per-email content inherits this cell's font/size/color -->
    <tr><td style="padding:28px;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#3a3a3c;">
      <#nested>
    </td></tr>
    <#-- Footer -->
    <tr><td style="padding:18px 28px;border-top:1px solid #e5e5e5;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;color:#6c6f7d;">
      This is an automated message from Diametral. If you weren't expecting it, you can safely ignore it.
    </td></tr>
  </table>
  <div style="font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:11px;letter-spacing:0.04em;color:#6c6f7d;padding:14px 0 0;">Diametral — Welcome to (the real)</div>
</td></tr></table>
</body>
</html>
</#macro>
