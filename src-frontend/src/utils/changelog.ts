export type TokenType = 'category' | 'keyword' | 'plain';

type TokenMatcher = {
  regex: RegExp;
  type: TokenType;
  groupName: string;
};

export type Token = {
  start: number;
  end: number;
  type: TokenType;
  value: string;
};

// const sequencerCommands = [
//   "ARP",
//   "ARC",
//   "CHA",
//   "DEL",
//   "GRV",
//   "HOP",
//   "RND",
//   "RNL",
//   "RET",
//   "REP",
//   "RTO",
//   "NTH",
//   "PSL",
//   "PBN",
//   "PVB",
//   "PVX",
//   "SCA",
//   "SCG",
//   "SED",
//   "5NG",
//   "TBL",
//   "THO",
//   "TIC",
//   "TBX",
//   "TPO",
//   "TSP",
//   "GGR",
//   "RMX",
//   "INS",
//   "NXT",
//   "KIL",
//   "OFF",
// ];

// const currentInstrumentCommands = [
//   "VOL",
// "PIT",
// "FIN",
// "OSC",
// "SIZ",
// "MUL",
// "WRP",
// "SCN",
// "FIL",
// "CUT",
// "RES",
// "AMP",
// "LIM",
// "PAN",
// "SNC",
// "ERR",
// "DRY",
// "SMX",
// "SDL",
// "SRV",
// ];

// const instrumentModsCommands = [

// ];

// const mixerEffectsCommands = [
//   "VMV",
// "VMX",
// "VDE",
// "VRE",
// "VIN",
// "USB",
// "EQI",
// "EQM",
// "VT1",
// "VT2",
// "VT3",
// "VT4",
// "VT5",
// "VT6",
// "VT7",
// "VT8",
// "XMT",
// "XMM",
// "XMF",
// "XMW",
// "XMR",
// "XDT",
// "XDF",
// "XDW",
// "XDR",
// "XRS",
// "XRD",
// "XRM",
// "XRF",
// "XRW",
// "XRH",
// "XRZ",
// "IMX",
// "IDE",
// "IRE",
// "VI2",
// "IM2",
// "ID2",
// "IR2",
// "DJC",
// "DJR",
// "DJT",
// "OTT",
// "OTC",
// "OTI",
// ];

const explicitTokens = ['model:01', 'model:02'].map((token) => ({
  regex: new RegExp(`(?<token>${token})`, 'gi'),
  type: 'keyword',
  groupName: 'token',
})) satisfies TokenMatcher[];

const tokenMatchers: TokenMatcher[] = [
  // {
  //   regex: /(?<=^)(?<token>(?:\w+ ){0,1}(?:\w)+)( -)/g,
  //   type: "category",
  //   groupName: "token",
  // },
  ...explicitTokens,
  // {
  //   regex: /(?<=\b)(?<token>(?:[A-Z0-9]*-?)[A-Z0-9]+)(?=\b)(?! -)/g,
  //   type: "keyword",
  //   groupName: "token",
  // },
  {
    regex: /(?<=\b)(?<token>[A-Z]{3})(?=\b)/g,
    type: 'keyword',
    groupName: 'token',
  },
];

// const tokenMatchers: TokenMatcher[] = [
// 	{
// 		// Matches sequences like " FX ", " PIT ", or " C-1 " with spaces as context
// 		// Named capturing group 'token' contains the target sequence
// 		regex: /(?:^|[^a-zA-Z])(?<token>[A-Z]+(?:-[A-Z]+)?)(?:[^a-zA-Z]|$)/g, // /\s(?<token>[A-Z]+(?:-[A-Z]+)?)\s/g,
// 		type: 'caps',
// 		groupName: 'token',
// 	},
// 	{
// 		// Matches numbers with spaces as context
// 		regex: /(^|\D)(?<token>\d+)(\D|$)/g, // /\s(?<token>\d+)\s/g,
// 		type: 'number',
// 		groupName: 'token',
// 	},
// ];

// const getMatchingTokens = (line: string, matcher: TokenMatcher): Token[] => {
// 	const { regex, type, groupName } = matcher;
// 	const tokens: Token[] = [];

// 	// Ensure the regex has the 'g' flag for global matching
// 	if (!regex.flags.includes('g')) {
// 		throw new Error('Regex must have global flag /g');
// 	}

// 	// Reset regex.lastIndex to ensure it starts matching from the beginning
// 	regex.lastIndex = 0;

// 	let match: RegExpExecArray | null;
// 	while ((match = regex.exec(line)) !== null) {
// 		const fullMatchStart = match.index;
// 		const groupValue = match.groups?.[groupName];

// 		if (groupValue === undefined) {
// 			continue; // Skip if the named group didn't match
// 		}

// 		// Find the position of the group within the full match
// 		const groupStartInMatch = match[0].indexOf(groupValue);
// 		const groupStart = fullMatchStart + groupStartInMatch;
// 		const groupEnd = groupStart + groupValue.length;

// 		tokens.push({
// 			start: groupStart,
// 			end: groupEnd,
// 			type,
// 			value: groupValue,
// 		});

// 		// Prevent infinite loops by advancing lastIndex if match is zero-length
// 		if (regex.lastIndex === fullMatchStart) {
// 			regex.lastIndex++;
// 		}
// 	}

// 	return tokens;
// };

// const getMatchingTokens = (line: string, matcher: TokenMatcher): Token[] => {
// 	const { regex, type, groupName } = matcher;
// 	const tokens: Token[] = [];

// 	regex.lastIndex = 0;

// 	let match: RegExpExecArray | null;
// 	while ((match = regex.exec(line)) !== null) {
// 		const matchStart = match.index;
// 		const groupValue = match.groups?.[groupName];

// 		if (groupValue === undefined) {
// 			regex.lastIndex = matchStart + 1;
// 			continue;
// 		}

// 		const groupStart = matchStart;
// 		const groupEnd = groupStart + groupValue.length;

// 		tokens.push({
// 			start: groupStart,
// 			end: groupEnd,
// 			type,
// 			value: groupValue,
// 		});

// 		// Advance lastIndex by 1 to check for overlapping matches
// 		regex.lastIndex = matchStart + 1;
// 	}

// 	return tokens;
// };

// export const tokenizeChangelogLine = (line: string): Token[] => {
// 	let tokens: Token[] = [];

// 	// Collect tokens from all matchers
// 	tokenMatchers.forEach((matcher) => {
// 		tokens = tokens.concat(getMatchingTokens(line, matcher));
// 	});

// 	// Sort tokens by start index
// 	tokens.sort((a, b) => a.start - b.start);

// 	// Build the final list of tokens, including plain text
// 	const finalTokens: Token[] = [];
// 	let currentIndex = 0;

// 	for (const token of tokens) {
// 		if (token.start > currentIndex) {
// 			// Add plain text between currentIndex and token.start
// 			finalTokens.push({
// 				start: currentIndex,
// 				end: token.start,
// 				type: 'plain',
// 				value: line.slice(currentIndex, token.start),
// 			});
// 		}

// 		finalTokens.push(token);
// 		currentIndex = token.end;
// 	}

// 	// Add any remaining plain text after the last matched token
// 	if (currentIndex < line.length) {
// 		finalTokens.push({
// 			start: currentIndex,
// 			end: line.length,
// 			type: 'plain',
// 			value: line.slice(currentIndex),
// 		});
// 	}

// 	return finalTokens;
// };

// export const tokenizeChangelogLine = (line: string): Token[] => {
// 	let tokens: Token[] = [];

// 	// Collect tokens from all matchers
// 	tokenMatchers.forEach((matcher) => {
// 		tokens = tokens.concat(getMatchingTokens(line, matcher));
// 	});

// 	// Sort tokens by start index
// 	tokens.sort((a, b) => a.start - b.start);

// 	// Build final tokens including plain text
// 	const finalTokens: Token[] = [];
// 	let currentIndex = 0;

// 	for (const token of tokens) {
// 		if (token.start > currentIndex) {
// 			// Add plain text between currentIndex and token.start
// 			finalTokens.push({
// 				start: currentIndex,
// 				end: token.start,
// 				type: 'plain',
// 				value: line.slice(currentIndex, token.start),
// 			});
// 		}

// 		finalTokens.push(token);
// 		currentIndex = token.end;
// 	}

// 	// Add any remaining plain text
// 	if (currentIndex < line.length) {
// 		finalTokens.push({
// 			start: currentIndex,
// 			end: line.length,
// 			type: 'plain',
// 			value: line.slice(currentIndex),
// 		});
// 	}

// 	return finalTokens;
// };

// Helper function to find group positions within a match
function getGroupPositions(match: RegExpExecArray): Array<{
  name: string | null;
  start: number;
  end: number;
}> {
  const positions: Array<{ name: string | null; start: number; end: number }> = [];
  const fullMatch = match[0];
  let currentIndexInMatch = 0; // Position within the full match

  // Iterate over match indices (1 to match.length - 1)
  for (let i = 1; i < match.length; i++) {
    const groupValue = match[i];
    if (groupValue === undefined) {
      continue;
    }

    // Find the position of the group within the full match
    const positionInMatch = fullMatch.indexOf(groupValue, currentIndexInMatch);

    if (positionInMatch === -1) {
      continue;
    }

    const start = match.index + positionInMatch;
    const end = start + groupValue.length;

    // Determine if the group is named
    const groupNames = match.groups ? Object.keys(match.groups) : [];
    const groupName = groupNames.find((name) => match.groups![name] === groupValue) || null;

    positions.push({ name: groupName, start, end });

    currentIndexInMatch = positionInMatch + groupValue.length;
  }

  return positions;
}

const getMatchingTokens = (
  line: string,
  matcher: TokenMatcher,
  occupiedIndices: boolean[],
): Token[] => {
  const { regex, type, groupName } = matcher;
  const tokens: Token[] = [];

  // Ensure the regex has the 'g' flag
  if (!regex.flags.includes('g')) {
    throw new Error('Regex must have global flag /g');
  }

  // Reset regex.lastIndex
  regex.lastIndex = 0;

  let match: RegExpExecArray | null;
  while ((match = regex.exec(line)) !== null) {
    // const fullMatchStart = match.index;
    // const fullMatchEnd = regex.lastIndex;

    // Get positions of all groups in this match
    const groupPositions = getGroupPositions(match);

    // Identify the named group and non-named groups
    let namedGroupPosition: { start: number; end: number } | null = null;

    for (const group of groupPositions) {
      if (group.name === groupName) {
        // This is the named group to include as a token
        namedGroupPosition = { start: group.start, end: group.end };
      } else if (group.name === null) {
        // Non-named capturing group; mark positions to delete
        for (let i = group.start; i < group.end; i++) {
          occupiedIndices[i] = true; // Mark as occupied (to delete)
        }
      }
    }

    // If the named group was found, create a token
    if (namedGroupPosition) {
      const { start: groupStart, end: groupEnd } = namedGroupPosition;
      const groupValue = line.slice(groupStart, groupEnd);

      // Check for overlaps with occupied indices
      let overlaps = false;
      for (let i = groupStart; i < groupEnd; i++) {
        if (occupiedIndices[i]) {
          overlaps = true;
          break;
        }
      }

      if (overlaps) {
        continue; // Skip this token due to overlap
      }

      // Mark the indices of the named group as occupied
      for (let i = groupStart; i < groupEnd; i++) {
        occupiedIndices[i] = true;
      }

      // Add the token
      tokens.push({
        start: groupStart,
        end: groupEnd,
        type,
        value: groupValue,
      });
    }

    // No need to mark unmatched parts of the match as occupied
    // They will be included in the output as plain text

    // Prevent infinite loops for zero-length matches
    if (regex.lastIndex === match.index) {
      regex.lastIndex++;
    }
  }

  return tokens;
};

export const tokenizeChangelogLine = (line: string): Token[] => {
  let tokens: Token[] = [];

  const occupiedIndices: boolean[] = Array.from<boolean>({
    length: line.length,
  }).fill(false);

  for (const matcher of tokenMatchers) {
    const matcherTokens = getMatchingTokens(line, matcher, occupiedIndices);
    tokens = tokens.concat(matcherTokens);
  }

  const finalTokens: Token[] = [];

  let currentIndex = 0;

  while (currentIndex < line.length) {
    if (occupiedIndices[currentIndex]) {
      currentIndex++;

      continue;
    }

    // Find the next range of unoccupied indices
    let endIndex = currentIndex;

    while (endIndex < line.length && !occupiedIndices[endIndex]) {
      endIndex++;
    }

    const text = line.slice(currentIndex, endIndex);

    finalTokens.push({
      start: currentIndex,
      end: endIndex,
      type: 'plain',
      value: text,
    });

    currentIndex = endIndex;
  }

  tokens = tokens.concat(finalTokens);

  tokens.sort((a, b) => a.start - b.start);

  return tokens;
};
