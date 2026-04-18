import * as fs from 'fs';
import * as path from 'path';

const IDL_DIR = path.resolve('idls');
const OUT_DIR = path.resolve('sdk/src/generated/instructions');

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

function resolveType(type: any): string {
  if (typeof type === 'string') {
    switch (type) {
      case 'u8': return 'number';
      case 'u16': return 'number';
      case 'u32': return 'number';
      case 'u64': return 'bigint | number';
      case 'i64': return 'bigint | number';
      case 'bool': return 'boolean';
      case 'bytes': return 'Uint8Array | Buffer';
      case 'publicKey': return 'PublicKey';
      case 'string': return 'string';
      default: return type;
    }
  }
  if (type.defined) return type.defined;
  if (type.array) return `Uint8Array | number[]`;
  if (type.vec) return `${resolveType(type.vec)}[]`;
  if (type.option) return `${resolveType(type.option)} | null`;
  return 'any';
}

function generateSerializerCall(name: string, type: any, serializer: string = 'serializer'): string {
  if (typeof type === 'string') {
    switch (type) {
      case 'u8': return `${serializer}.writeU8(${name});`;
      case 'u16': return `${serializer}.writeU16(${name});`;
      case 'u32': return `${serializer}.writeU32(${name});`;
      case 'u64': return `${serializer}.writeU64(${name});`;
      case 'i64': return `${serializer}.writeI64(${name});`;
      case 'bool': return `${serializer}.writeBool(${name});`;
      case 'bytes': return `${serializer}.writeVec(Buffer.from(${name}));`;
      case 'publicKey': return `${serializer}.writePubkey(${name});`;
      case 'string': return `${serializer}.writeString(${name});`;
      default: return `// TODO: defined type ${type}`;
    }
  }
  if (type.defined) {
    return `serialize${type.defined}(${serializer}, ${name});`;
  }
  if (type.array) {
    return `${serializer}.writeFixedArray(Buffer.from(${name}), ${type.array[1]});`;
  }
  if (type.option) {
    const innerType = type.option;
    return `${serializer}.writeOption(${name}, (v) => { ${generateSerializerCall('v', innerType, serializer)} });`;
  }
  return `// Unknown type for ${name}`;
}

function generateStructSerializer(structName: string, fields: any[]): string {
    const lines = [];
    lines.push(`export function serialize${structName}(serializer: WincodeSerializer, value: ${structName}) {`);
    for (const field of fields) {
        lines.push(`  ${generateSerializerCall(`value.${field.name}`, field.type)}`);
    }
    lines.push(`}`);
    return lines.join('\n');
}

function generateClient(idlName: string, idl: any) {
  const isReceipts = idlName.includes('receipts');
  
  let out = `import { PublicKey, TransactionInstruction, AccountMeta } from '@solana/web3.js';\n`;
  out += `import { Buffer } from 'buffer';\n`;
  out += `import { WincodeSerializer } from '../../utils/wincode';\n\n`;

  // 1. Generate Types
  if (idl.types) {
    for (const typeDef of idl.types) {
      if (typeDef.type.kind === 'struct') {
        out += `export interface ${typeDef.name} {
`;
        for (const field of typeDef.type.fields) {
          out += `  ${field.name}: ${resolveType(field.type)};\n`;
        }
        out += `}

`;
        out += generateStructSerializer(typeDef.name, typeDef.type.fields) + `\n\n`;
      }
    }
  }

  // 2. Generate Instructions
  const addr = idl.metadata?.address || "11111111111111111111111111111111";
  out += `export const PROGRAM_ID = new PublicKey('${addr}');\n\n`;

  if (idl.instructions) {
    idl.instructions.forEach((ix: any, index: number) => {
      const ixName = ix.name;
      
      const args = ix.args || [];
      const accounts = ix.accounts || [];

      const argsSig = args.map((a: any) => `${a.name}: ${resolveType(a.type)}`).join(', ');
      const accountsSig = `accounts: { ${accounts.map((a: any) => `${a.name}: PublicKey`).join(', ')} }`;

      out += `export function create${ixName}Instruction(${argsSig}${args.length > 0 ? ', ' : ''}${accountsSig}, programId: PublicKey = PROGRAM_ID): TransactionInstruction {
`;
      out += `  const serializer = new WincodeSerializer();
`;
      
      let discVal = index;
      let discType = isReceipts ? 'u8' : 'u32'; 
      if (ix.discriminant) {
          discVal = ix.discriminant.value;
          discType = ix.discriminant.type;
      }

      if (discType === 'u8') {
          out += `  serializer.writeU8(${discVal});\n`;
      } else {
          out += `  serializer.writeU32(${discVal});\n`;
      }

      for (const arg of args) {
        out += `  ${generateSerializerCall(arg.name, arg.type, 'serializer')}\n`;
      }

      out += `\n  const keys: AccountMeta[] = [\n`;
      for (const acc of accounts) {
        out += `    { pubkey: accounts.${acc.name}, isSigner: ${acc.isSigner}, isWritable: ${acc.isMut} },\n`;
      }
      out += `  ];\n\n`;

      out += `  return new TransactionInstruction({
`;
      out += `    keys,
`;
      out += `    programId,
`;
      out += `    data: serializer.data,
`;
      out += `  });
`;
      out += `}

`;
    });
  }

  const outFile = path.join(OUT_DIR, `${idlName.replace('.json', '')}.ts`);
  fs.writeFileSync(outFile, out);
  console.log(`Generated ${outFile}`);
}

fs.readdirSync(IDL_DIR).forEach(file => {
  if (file.endsWith('.json')) {
    const idlContent = fs.readFileSync(path.join(IDL_DIR, file), 'utf-8');
    const idl = JSON.parse(idlContent);
    generateClient(file, idl);
  }
});
