function notifyOwnerEmail(subject)
props=java.lang.System.getProperties;
props.setProperty('mail.smtp.auth', 'true');
props.setProperty('mail.smtp.starttls.enable', 'true');
props.setProperty('mail.smtp.port', '587');

setpref('Internet', 'SMTP_Server', 'smtp.gmail.com')
setpref('Internet', 'E_mail', 'linlabrandom@gmail.com')
setpref('Internet', 'SMTP_Username', 'linlabrandom@gmail.com')
setpref('Internet', 'SMTP_Password', 'n0tImportant%%$')

sendmail('olaoluwa.ojo@ontariotechu.net', subject, ...
'There has been an error! Check the experiment.');
% sendmail('jonathan.couture@ontariotechu.net', subject, ...
%     'There has been an error! Check the experiment.');

disp("Email Notification Sent");
% disp('Email notifications disabled');
end
