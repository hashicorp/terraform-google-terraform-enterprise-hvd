# Troubleshooting

## User Data Script

GCP uses a go app called google_metadata_scrpt_runner **GCP DOES NOT support CLOUD-INIT (even under RHEL) without help generally if your setting CLOUD init you need a custom image **

<https://cloud.google.com/compute/docs/instances/startup-scripts/linux>
<https://pkg.go.dev/github.com/GoogleCloudPlatform/guest-agent/google_metadata_script_runner#section-sourcefiles>

The script can be run locally from the instance

```sh
sudo google_metadata_script_runner startup
```

and you can view logs with;

```sh
sudo journalctl -u google-startup-scripts.service
```

<https://cloud.google.com/compute/docs/instances/startup-scripts/linux#rerunning>
under LFS the scripts can be found at

- `/usr/share/cloud`
- `/var/lib/cloud/instances`

To monitor the progress of the install (_user_data_ script/cloud-init process), SSH (or other similarly method of connectivity) into the EC2 instance and run `journalctl -xu cloud-final -f` to tail the logs (or remove the `-f` if the cloud-init process has finished).  If the operating system is Ubuntu, logs can also be viewed via `tail -f /var/log/cloud-init-output.log`.
