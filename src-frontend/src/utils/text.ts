export const formatDuration = (duration: number): string => {
  const seconds = Math.floor((duration / 1000) % 60);
  const minutes = Math.floor((duration / (1000 * 60)) % 60);
  const hours = Math.floor((duration / (1000 * 60 * 60)) % 24);
  const days = Math.floor(duration / (1000 * 60 * 60 * 24));

  const secondsDisplay = seconds < 10 ? `0${seconds}` : seconds;
  const minutesDisplay = minutes < 10 ? `0${minutes}` : minutes;
  const hoursDisplay = hours < 10 ? `0${hours}` : hours;

  if (days > 0) {
    return `${days}d ${hoursDisplay}h ${minutesDisplay}m ${secondsDisplay}s`;
  } else if (hours > 0) {
    return `${hoursDisplay}h ${minutesDisplay}m ${secondsDisplay}s`;
  } else if (minutes > 0) {
    return `${minutesDisplay}m ${secondsDisplay}s`;
  } else {
    return `${secondsDisplay}s`;
  }
};
