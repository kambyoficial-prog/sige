    router.refresh();
  }

  async function setAttendance(
    studentId: string,
    status: "PRESENT" | "ABSENT" | "EXCUSED" | "LATE",
  ) {
    if (!selectedSession) return;
    const minutes = status === "LATE" ? Number(lateMinutes[studentId] ?? "") : undefined;
    if (status === "LATE" && (!Number.isInteger(minutes) || minutes < 1)) {
      setError("Indique os minutos de atraso antes de registar.");
      return;
    }

    const minutesLate = minutes;
    const result = await recordSessionAttendanceAction({