export async function runSchedule(device, clock, steps) {
  const ordered = [...steps].sort((a, b) => a.at - b.at)
  for (const step of ordered) {
    await clock.at(step.at)
    if (!device.page || device.page.isClosed()) return
    await device.act(step.name, step.key ?? null, step.run).catch(() => null)
  }
}
