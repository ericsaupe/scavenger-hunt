import { TEAMS, PUSH, TIMELINE } from "./config.js"
import { CLIP_20, CLIP_70 } from "./lib/fixtures.js"

const push = (name) => (PUSH.all.includes(name) ? "all" : PUSH.noAnnouncements.includes(name) ? "noAnnouncements" : null)
const u = (at, item, extra = {}) => ({ at, item, ...extra })
const c = (at, text, extra = {}) => ({ at, text, ...extra })

export function buildPlans(items) {
  const i = (n) => items[n % items.length]
  const base = (name, team, overrides) => ({ name, team, push: push(name), uploads: [], chat: [], votes: [], ...overrides })
  const love = (...ats) => ats.map((at) => ({ at, value: "love" }))
  const flag = (at) => [{ at, value: "flag" }]

  return [
    base("blue-1", TEAMS.blue, { joinAt: 0.4, create: true, resultsPeekAt: 0.95,
      uploads: [u(8.0, i(0)), u(9.5, i(1)), u(11, i(2)), u(12.5, i(3)), u(14, i(4)), u(15.5, i(5)), u(17, i(6))],
      chat: [c(7.6, "Blue Bandits rolling out."), c(13.0, "BLUE. DOOR. Next question."), c(23.5, "ok that is a good door"), c(30.5, "we were robbed")],
      votes: love(22.3, 23.6, 26.2, 28.4, 30.1, 32.0) }),
    base("blue-2", TEAMS.blue, { joinAt: 0.55, pick: true,
      uploads: [u(8.1, i(0), { kind: "photo-retake" }), u(8.8, i(7)), u(10.3, i(8)), u(11.8, i(9)), u(13.3, i(10)), u(14.8, i(11)), u(16.3, i(12)), u(17.8, i(13))],
      chat: [c(9.8, "got the mailbox, who has the mural?"), c(25.2, "nice shot nina")],
      votes: love(22.6, 24.8, 27.6, 29.3, 31.4) }),
    base("blue-3", TEAMS.blue, { joinAt: 0.7, pick: true,
      uploads: [u(9.0, i(14), { file: CLIP_20, kind: "video" }), u(10.0, i(15), { file: CLIP_70, kind: "video-too-long", expect: "banner" }), u(12.0, i(16), { file: CLIP_20, kind: "video" }), u(13.5, i(17)), u(16.0, i(18))],
      chat: [c(12.3, "video of the fountain incoming")],
      votes: [...love(22.9, 25.9, 28.9), ...flag(24.1)] }),
    base("red-1", TEAMS.red, { joinAt: 0.85, create: true,
      uploads: [u(8.3, i(0)), u(10, i(1)), u(12, i(2)), u(14, i(3)), u(14.6, i(4)), u(15.2, i(5)), u(15.8, i(6)), u(16.4, i(7)), u(17, i(8)), u(17.6, i(9))],
      chat: [c(8.6, "Anyone found the blue car yet? We checked every driveway on Maple."), c(15.0, "Rockets taking off now"), c(24.4, "that one is clearly fake"), c(31.9, "GG everyone")],
      votes: [...love(22.4, 25.1, 27.9, 30.7), ...flag(24.1)] }),
    base("red-2", TEAMS.red, { joinAt: 1.0, pick: true,
      uploads: [u(9, i(10)), u(11.5, i(11)), u(14.3, i(12)), u(14.9, i(13)), u(15.5, i(14)), u(16.1, i(15)), u(16.7, i(16)), u(17.3, i(17)), u(17.9, i(18))],
      chat: [c(11.6, "Dev here, we are at the park"), c(29.1, "that door is teal at best")],
      votes: love(23.2, 26.6, 29.9, 32.4), expireAt: 23 }),
    base("red-3", TEAMS.red, { joinAt: 1.15, pick: true,
      uploads: [u(10.5, i(19)), u(12.8, i(20)), u(13.5, i(3), { expect: "queued", kind: "photo-offline-collision" }), u(16.5, i(22)), u(18, i(23))],
      offline: [{ from: 13.0, to: 15.0 }],
      chat: [c(16.0, "my signal died for a bit, photos back?")],
      votes: love(23.9, 27.3, 31.1) }),
    base("green-1", TEAMS.green, { joinAt: 1.3, create: true,
      uploads: [u(8.5, i(0)), u(10.5, i(1)), u(12.5, i(2)), u(14.5, i(3)), u(16.5, i(4)), u(19.6, i(5), { expect: "banner", kind: "photo-after-end" })],
      chat: [c(10.9, "Green Machine checking in"), c(26.9, "flag that one, the door is purple")],
      votes: [...love(22.1, 25.6, 28.1, 32.7), ...flag(24.1)] }),
    base("green-2", TEAMS.green, { joinAt: 1.45, pick: true,
      uploads: [u(9.3, i(6)), u(11.3, i(7)), u(13.3, i(8)), u(15.3, i(9)), u(18.0, i(10), { expect: "queued", kind: "photo-grace" })],
      offline: [{ from: 17.3, to: 19.5 }],
      chat: [c(14.2, "Oscar found the fountain first, sorry Blue")],
      votes: love(23.4, 26.0, 29.6) }),
    base("owls-1", TEAMS.owls, { joinAt: 1.6, create: true,
      uploads: [u(8.7, i(0)), u(11.7, i(1)), u(14.7, i(2)), u(17.7, i(3))],
      chat: [c(7.3, "Owls are go"), c(9.2, "Not telling."), c(11.0, "fast one"), c(11.01, "second within a second", { kind: "throttle" }), c(13.4, "who put a flamingo on Elm"), c(16.2, "owls never lose"), c(22.7, "boo"), c(27.0, "that is not a blue door"), c(30.2, "ok fine it is blue"), c(32.9, "rematch next month")],
      votes: [...love(22.5, 25.3), ...flag(24.1)] }),
    base("owls-2", TEAMS.owls, { joinAt: 1.75, pick: true,
      uploads: [u(9.9, i(4)), u(12.9, i(5)), u(15.9, i(6))],
      chat: [c(8.1, "Jo here. Hooting."), c(10.4, "pizza?? where"), c(12.2, "this chat is lagging my phone (it is not)"), c(15.1, "Owls 3, everyone else 0 (emotionally)"), c(18.2, "last photo in"), c(24.0, "wait go back"), c(28.6, "boooo"), c(31.6, "fine")],
      browse: { at: 26.0, backAt: 27.5 },
      votes: love(23.0, 28.3, 32.2) }),
    base("fox-1", TEAMS.foxes, { joinAt: 9.0, create: true,
      uploads: [u(9.6, i(0)), u(12.6, i(1)), u(15.6, i(2))],
      chat: [c(9.3, "Foxes are late but here"), c(25.7, "quiet team, loud photos")],
      votes: love(22.8, 26.4, 30.4) }),
    base("fox-2", TEAMS.foxes, { joinAt: 8.5, pick: true, watchTeamsFrom: 8.5, pickAt: 9.4,
      uploads: [u(11.1, i(3)), u(14.1, i(4)), u(17.1, i(5))],
      chat: [c(17.4, "Kai here, we found the mural"), c(29.8, "that is my photo!!")],
      votes: love(23.7, 27.1, 31.7) })
  ]
}

export const WATCH_AT = TIMELINE.show + 0.5
