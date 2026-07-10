output "grafana_private_ip" {
  value = module.grafana.grafana_private_ip
}

output "prometheus_private_ip" {
  value = module.prometheus.prometheus_private_ip
}
