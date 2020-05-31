function notifyOwnerEmail(subject)
props=java.lang.System.getProperties;
props.setProperty('mail.smtp.auth', 'true');
props.setProperty('mail.smtp.starttls.enable', 'true');
props.setProperty('mail.smtp.port', '587');

setpref('Internet', 'SMTP_Server', 'smtp.gmail.com')
setpref('Internet', 'E_mail', 'linlabemail@gmail.com')
setpref('Internet', 'SMTP_Username', 'linlabemail@gmail.com')
setpref('Internet', 'SMTP_Password', 'linlab11')

sendmail('olaoluwa.ojo@uoit.net', subject, ...
'There has been an error! Check the experiment.');

disp("Email Notification Sent");
end