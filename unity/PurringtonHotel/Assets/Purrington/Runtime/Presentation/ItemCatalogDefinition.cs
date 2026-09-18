using System;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
    [CreateAssetMenu(menuName="Purrington/Item catalogue")]
    public sealed class ItemCatalogDefinition : ScriptableObject
    {
        public ItemDefinition[] items;
        public void Apply()
        {
            if(items==null)return;
            foreach(var item in items)
            {
                if(item==null||string.IsNullOrEmpty(item.id)||item.price<0||double.IsNaN(item.price)||double.IsInfinity(item.price)||item.width<=0||item.depth<=0||float.IsNaN(item.width)||float.IsInfinity(item.width)||float.IsNaN(item.depth)||float.IsInfinity(item.depth))continue;
                int index=Array.FindIndex(Catalog.All,x=>x.id==item.id);
                if(index>=0)Catalog.All[index]=item;
            }
        }
    }
}
